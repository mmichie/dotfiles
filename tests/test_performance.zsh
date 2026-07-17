#!/usr/bin/env zsh
# Structural performance gates. No wall-clock assertions — those are
# machine-dependent and live in `just profile` (real env, warm) and
# `just profile-cold` (sandbox, cold vs warm). What IS asserted here are the
# machine-independent invariants whose loss is what actually makes startup
# slow:
#
#   - warm boots run exactly one compinit, on the -C fast path
#     (the manual /etc/zshrc re-source bug was a hidden second compinit)
#   - warm boots regenerate no _refresh_cache tool inits
#   - warm boots rewrite nothing under the cache dir at all
#     (compared by INODE, not mtime: consecutive boots land within the same
#     second, but every rebuild path goes through rm/mv and changes inode)
#   - every lib module is sourced exactly once
#   - no duplicate precmd/preexec hook registrations (per-command cost)
#
# Two consecutive warm boots are traced: the /etc/zshrc bug class is
# "boot N mutates state that boot N+1 inherits", which a single warm boot
# cannot see.

source "${0:A:h}/lib.zsh"

zmodload -F zsh/stat b:zstat 2>/dev/null || { t_skip "performance gates" "zsh/stat unavailable"; t_finish }

# Inode+size fingerprint of every file under a dir, dotfiles included —
# without (D) this would silently miss .zcompdump and gate nothing.
_cache_fingerprint() {
    local f
    local -a lines st
    for f in "$1"/**/*(.DN); do
        zstat -A st +inode "$f"
        lines+=("${f#$1/}:inode=$st[1]")
    done
    print -rl -- "${lines[@]}"
}

# Boot the sandbox with xtrace, trace to $2. timeout(1) guards against the
# hang class (e.g. something opening /dev/tty) where available.
_traced_boot() {
    local home="$1" trace="$2"
    local -a maybe_timeout
    have timeout && maybe_timeout=(timeout 30)
    _sandbox_env_args "$home"
    "${maybe_timeout[@]}" env -i "${reply[@]}" \
        zsh --no-globalrcs -x -i -c 'print -r -- M_BOOT_DONE' >"$trace.out" 2>"$trace"
}

typeset sb
sb="$(make_sandbox_home)"

# ── Cold boot: build all caches (traced, to keep the gate honest) ────
typeset coldtrace="$T_SCRATCH/cold.trace"
_traced_boot "$sb" "$coldtrace"
typeset dump="$sb/.cache/zsh/.zcompdump"
if [[ -s "$dump" ]]; then
    t_pass "cold boot writes the compinit dump (gate precondition)"
else
    t_fail "cold boot writes the compinit dump (gate precondition)" "missing: $dump"
fi

# Gate sanity: the warm-boot assertion below greps for _write_cache eval
# lines, so the same pattern must be visible on a cold boot — otherwise a
# rename in 50-integrations.zsh would turn the gate vacuous (which is
# exactly how the original `_refresh_cache> eval` pattern died: the eval
# moved into _write_cache and the gate silently matched nothing).
typeset any_tool
any_tool=$(run_sandbox_zsh "$sb" \
    'print -rn -- $(( $+commands[fzf] || $+commands[atuin] || $+commands[direnv] || $+commands[vivid] || $+commands[zoxide] ))' 2>/dev/null)
if [[ "$any_tool" == 1 ]]; then
    if grep -qE '_write_cache:[0-9]+> eval' "$coldtrace"; then
        t_pass "cold boot regenerates caches through _write_cache (gate is non-vacuous)"
    else
        t_fail "cold boot regenerates caches through _write_cache (gate is non-vacuous)" \
            "no _write_cache eval in cold trace — warm-boot gate would match nothing"
    fi
else
    t_skip "cold-boot gate sanity" "no cached tools visible in sandbox"
fi

typeset baseline
baseline="$(_cache_fingerprint "$sb/.cache/zsh")"

# ── Two traced warm boots ────────────────────────────────────────────
typeset -i n
typeset trace compinit_calls refresh_evals
for n in 1 2; do
    trace="$T_SCRATCH/warm$n.trace"
    _traced_boot "$sb" "$trace"

    if grep -q "M_BOOT_DONE" "$trace.out"; then
        t_pass "warm boot $n completes"
    else
        t_fail "warm boot $n completes" "no completion marker (hang or crash?)"
    fi

    # Exactly one compinit invocation, and it must be the -C fast path.
    compinit_calls=$(grep -cE '> compinit( |$)' "$trace")
    assert_eq "$compinit_calls" "1" "warm boot $n runs exactly one compinit"
    if grep -qE '> compinit -C ' "$trace"; then
        t_pass "warm boot $n compinit takes the -C fast path"
    else
        t_fail "warm boot $n compinit takes the -C fast path" \
            "$(grep -E '> compinit( |$)' "$trace" | head -2)"
    fi

    # The cache layer must not regenerate anything on a warm boot. The
    # eval lives in _write_cache (cold-trace-verified above).
    refresh_evals=$(grep -cE '_write_cache:[0-9]+> eval' "$trace")
    assert_eq "$refresh_evals" "0" "warm boot $n regenerates no tool-init caches"
done

# ── Module sourcing: each lib module exactly once (last trace) ───────
typeset -a expected sourced
expected=("$ZSH_CONF"/.zsh/lib/[0-9]*.zsh(N:t))
sourced=(${(f)"$(grep -oE '> source [^ ]*/lib/[0-9][^ ]*\.zsh' "$trace")"})
sourced=("${(@)sourced##* source *lib/}")
# (@u), not (u): inside double quotes a bare (u) joins the array into one
# string first, making the unique-count always 1.
assert_eq "${#sourced}" "${#expected}" "all ${#expected} lib modules sourced"
assert_eq "${#${(@u)sourced}}" "${#sourced}" "no lib module sourced twice"

# ── Nothing under the cache dir rewritten across both warm boots ─────
typeset final
final="$(_cache_fingerprint "$sb/.cache/zsh")"
if [[ "$final" == "$baseline" ]]; then
    t_pass "warm boots rewrite nothing under the cache dir"
else
    t_fail "warm boots rewrite nothing under the cache dir" \
        "$(diff <(print -r -- "$baseline") <(print -r -- "$final") 2>/dev/null | head -4)"
fi

# ── Hook hygiene: no duplicate registrations ─────────────────────────
typeset hooks
hooks=$(run_sandbox_zsh "$sb" '
typeset -a v
for arr in precmd_functions preexec_functions chpwd_functions; do
    v=("${(@P)arr}")
    print -r -- "$arr:${#v}:${#${(@u)v}}"
done' 2>/dev/null)
typeset line name total uniq
for line in ${(f)hooks}; do
    name="${line%%:*}"
    total="${${line#*:}%%:*}"
    uniq="${line##*:}"
    assert_eq "$total" "$uniq" "no duplicate $name registrations ($total hooks)"
done

t_finish
