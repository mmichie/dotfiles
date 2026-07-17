#!/usr/bin/env zsh
# Fault injection: boot the config against deliberately damaged state and
# hostile environments. The invariant is graceful degradation — a fault may
# cost one noisy boot, but never a broken shell and never a fault that
# every future shell keeps paying for.
#
#   - corrupt tool-init cache      -> quarantined + regenerated SAME boot
#   - corrupt .zcompdump           -> completions rebuilt SAME boot
#   - corrupt-but-newer .zwc       -> silent fallback, no false quarantine
#   - generator emitting garbage   -> refused at write time, never cached
#   - unwritable cache dir         -> boot completes, degraded
#   - HOME containing a space      -> boots clean (quoting sweep)
#   - minimal PATH (no tools)      -> boots clean
#   - concurrent cold boots        -> all complete; next boot clean

source "${0:A:h}/lib.zsh"

typeset sb='' out='' errf=''

# Boot stderr minus the known no-tty ZLE noise, newline-joined.
_boot_noise() {
    local -a lines
    lines=(${(f)"$(<$1)"})
    lines=(${lines:#*can?t change option: zle*})
    print -r -- "${(j: | :)lines}"
}

# ── Corrupt tool-init cache: quarantined and healed in the same boot ──
sb="$(make_sandbox_home)"
run_sandbox_zsh "$sb" 'exit' >/dev/null 2>&1
typeset victim=''
typeset c
for c in atuin-init fzf-init direnv-hook zoxide-init; do
    [[ -f "$sb/.cache/zsh/$c.zsh" ]] && { victim="$sb/.cache/zsh/$c.zsh"; break }
done
if [[ -n "$victim" ]]; then
    print -r -- '(((( this is not zsh <<<' >| "$victim"
    command rm -f "$victim.zwc"     # source file must be authoritative
    errf="$T_SCRATCH/heal.err"
    out=$(run_sandbox_zsh "$sb" 'print -r -- M_END' 2>"$errf")
    assert_contains "$out" "M_END" "boot completes with a corrupt ${victim:t}"
    assert_contains "$(<$errf)" "quarantined corrupt init cache" \
        "corrupt cache is quarantined (visible on stderr)"
    if zsh --no-globalrcs -n "$victim" 2>/dev/null && [[ -s "$victim" ]]; then
        t_pass "cache regenerated to parseable content in the SAME boot"
    else
        t_fail "cache regenerated to parseable content in the SAME boot" \
            "content: $(head -c 60 "$victim" 2>&1)"
    fi
    out=$(run_sandbox_zsh "$sb" 'print -r -- M_END' 2>"$errf")
    assert_contains "$out" "M_END" "next boot completes"
    assert_eq "$(_boot_noise "$errf")" "" "next boot stderr clean (fault fully healed)"
else
    t_skip "corrupt tool-init cache heals" "no sourced init caches in sandbox (no tools)"
fi

# ── Corrupt-but-newer .zwc beside a healthy cache: no false quarantine ─
# zsh validates wordcode and falls back to the source file on its own;
# the heal layer must not mistake that for corruption.
sb="$(make_sandbox_home)"
run_sandbox_zsh "$sb" 'exit' >/dev/null 2>&1
victim=''
for c in atuin-init fzf-init direnv-hook zoxide-init; do
    [[ -f "$sb/.cache/zsh/$c.zsh.zwc" ]] && { victim="$sb/.cache/zsh/$c.zsh"; break }
done
if [[ -n "$victim" ]]; then
    chmod +w "$victim.zwc"
    print -r -- 'CORRUPT WORDCODE' >| "$victim.zwc"
    touch "$victim.zwc"
    errf="$T_SCRATCH/zwc.err"
    out=$(run_sandbox_zsh "$sb" 'print -r -- M_END' 2>"$errf")
    assert_contains "$out" "M_END" "boot completes with a corrupt ${victim:t}.zwc"
    assert_eq "$(_boot_noise "$errf")" "" "corrupt .zwc boots clean (silent fallback to source)"
    if [[ -s "$victim" ]] && zsh --no-globalrcs -n "$victim" 2>/dev/null; then
        t_pass "healthy cache not quarantined over its corrupt .zwc"
    else
        t_fail "healthy cache not quarantined over its corrupt .zwc" "cache was removed or damaged"
    fi
else
    t_skip "corrupt .zwc fallback" "no compiled init caches in sandbox (no tools)"
fi

# ── Corrupt compinit dump with a MATCHING fpath fingerprint ───────────
# The nasty case: compinit -C trusts the dump, the fingerprint cannot see
# corruption, so without the .zshrc self-heal every future shell boots
# with completion dead. Must rebuild in the same boot and return to the
# -C fast path on the next one.
sb="$(make_sandbox_home)"
run_sandbox_zsh "$sb" 'exit' >/dev/null 2>&1
typeset dump="$sb/.cache/zsh/.zcompdump"
if [[ -s "$dump" ]]; then
    print -r -- 'GARBAGE ((( not a dump' >| "$dump"
    command rm -f "$dump.zwc"
    out=$(run_sandbox_zsh "$sb" \
        'print -r -- "M_COMPS=$(( ${#_comps} > 0 )) M_CD=${_comps[cd]} M_END"' \
        2>/dev/null)
    assert_contains "$out" "M_END"      "boot completes with a corrupt compinit dump"
    assert_contains "$out" "M_COMPS=1"  "completion system repopulated in the SAME boot"
    assert_contains "$out" "M_CD=_cd"   "cd completer restored in the SAME boot"
    if [[ -s "$dump" && "$(head -c 7 "$dump")" != "GARBAGE" ]]; then
        t_pass "dump rebuilt on disk"
    else
        t_fail "dump rebuilt on disk" "dump still garbage or empty"
    fi
    # Next boot: clean stderr AND back on the -C fast path (the heal must
    # re-stamp the fingerprint, not force full compinit forever).
    errf="$T_SCRATCH/dump2.err"
    typeset trace="$T_SCRATCH/dump2.trace"
    typeset -a maybe_timeout
    have timeout && maybe_timeout=(timeout 30)
    _sandbox_env_args "$sb"
    "${maybe_timeout[@]}" env -i "${reply[@]}" zsh --no-globalrcs -x -i -c \
        'print -r -- M_END' </dev/null >"$T_SCRATCH/dump2.out" 2>"$trace"
    if grep -q "M_END" "$T_SCRATCH/dump2.out"; then
        t_pass "boot after dump heal completes"
    else
        t_fail "boot after dump heal completes"
    fi
    if grep -qE '> compinit -C ' "$trace" && ! grep -qE '> compinit -i ' "$trace"; then
        t_pass "boot after dump heal is back on the compinit -C fast path"
    else
        t_fail "boot after dump heal is back on the compinit -C fast path" \
            "$(grep -E '> compinit' "$trace" | head -2)"
    fi
else
    t_fail "corrupt compinit dump heals" "precondition: cold boot wrote no dump"
fi

# ── Generator emitting garbage: refused at write time ────────────────
# A tool that exits 0 while printing junk to stdout (update banners,
# half-broken init) must never be installed as a sourceable cache. Data
# caches (no .zsh suffix) stay byte-transparent.
typeset gdir="$T_SCRATCH/genval"
mkdir -p "$gdir"
out=$(SHELL_CACHE_DIR="$gdir" zsh --no-globalrcs -f -c '
source "'"$ZSH_CONF"'/.zsh/lib/50-integrations.zsh" 2>/dev/null
_refresh_cache "'"$gdir"'/bad-init.zsh" "print -r -- \"((( broken\"" /nonexistent
print -r -- "BADRC=$?"
_refresh_cache "'"$gdir"'/raw-data" "print -r -- \"((( broken\"" /nonexistent
print -r -- "RAWRC=$?"
' 2>/dev/null)
assert_contains "$out" "BADRC=1" "unparseable generator output is refused for .zsh caches"
assert_contains "$out" "RAWRC=0" "data caches stay byte-transparent"
typeset -a leftovers
leftovers=("$gdir"/bad-init.zsh*(N))
assert_eq "${#leftovers}" "0" "refused generation leaves no cache, sidecar, or temp file"
if [[ -s "$gdir/raw-data" ]]; then
    t_pass "data cache written despite unparseable bytes"
else
    t_fail "data cache written despite unparseable bytes"
fi

# ── _init_from_cache heals without a fresh invalidator ────────────────
# Corruption strikes BETWEEN boots: command fingerprint and mtimes all
# still match, so _refresh_cache alone would keep the corpse forever.
out=$(SHELL_CACHE_DIR="$gdir" zsh --no-globalrcs -f -c '
source "'"$ZSH_CONF"'/.zsh/lib/50-integrations.zsh" 2>/dev/null
cmd="print -r -- \"typeset -g T_HEALED=yes\""
_refresh_cache "'"$gdir"'/heal.zsh" "$cmd" /nonexistent || print -r -- "SETUP_FAILED"
print -r -- "(((corrupted" >| "'"$gdir"'/heal.zsh"
command rm -f "'"$gdir"'/heal.zsh.zwc"
T_HEALED=no
_init_from_cache "'"$gdir"'/heal.zsh" "$cmd" /nonexistent
print -r -- "HEALRC=$? HEALED=$T_HEALED"
' 2>/dev/null)
assert_contains "$out" "HEALRC=0 HEALED=yes" \
    "_init_from_cache regenerates and sources a corrupted cache in-process"

# ── Unwritable cache dir: boot survives, degraded ─────────────────────
if (( EUID == 0 )); then
    t_skip "unwritable cache dir" "running as root (permissions not enforced)"
else
    sb="$(make_sandbox_home)"
    mkdir -p "$sb/.cache/zsh"
    chmod 500 "$sb/.cache/zsh"
    out=$(run_sandbox_zsh "$sb" 'print -r -- "M_END rc0=$?"' 2>/dev/null)
    chmod 700 "$sb/.cache/zsh"
    assert_contains "$out" "M_END" "boot completes with an unwritable cache dir"
fi

# ── HOME containing a space: full boot, correct PATH head ─────────────
typeset spacehome="$T_SCRATCH/space home/h"
mkdir -p "$spacehome/tmp"
for c in .zshrc .zshenv .zprofile .zsh; do
    ln -s "$ZSH_CONF/$c" "$spacehome/$c"
done
if [[ -n "$T_AGENT_SOCK" ]]; then
    mkdir -p "$spacehome/Library/Group Containers/2BUA8C4S2C.com.1password/t" "$spacehome/.1password"
    ln -s "$T_AGENT_SOCK" "$spacehome/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
    ln -s "$T_AGENT_SOCK" "$spacehome/.1password/agent.sock"
fi
errf="$T_SCRATCH/space.err"
out=$(run_sandbox_zsh "$spacehome" 'print -r -- "M_END path1=${path[1]}"' 2>"$errf")
assert_contains "$out" "M_END"                  "HOME with a space boots"
assert_contains "$out" "path1=$spacehome/bin"   "HOME with a space keeps PATH head"
assert_eq "$(_boot_noise "$errf")" "" "HOME with a space boots with clean stderr"

# ── Minimal PATH: no integrations, still a clean boot ─────────────────
# Needs system mkdir/etc. outside the nix build sandbox; skip where /bin
# is not a thing.
if [[ -x /bin/mkdir || -x /usr/bin/mkdir ]]; then
    sb="$(make_sandbox_home)"
    _sandbox_env_args "$sb"
    reply=("${(@)reply:#PATH=*}")
    reply+=(PATH="$T_AGENT_STUBS:/usr/bin:/bin")
    errf="$T_SCRATCH/minpath.err"
    out=$(env -i "${reply[@]}" "${commands[zsh]:-zsh}" --no-globalrcs -i -c \
        'print -r -- M_END' </dev/null 2>"$errf")
    assert_contains "$out" "M_END" "boot completes with PATH=/usr/bin:/bin (no tools)"
    assert_not_contains "$(<$errf)" "command not found" \
        "no unguarded tool invocation on a bare PATH"
else
    t_skip "minimal PATH boot" "no /bin outside the build sandbox"
fi

# ── Concurrent cold boots (tmux restoring many panes at once) ─────────
# All racers must finish; whatever the cache races produced, the next
# boot must be clean — mv-atomic caches plus quarantine make corruption
# at worst a one-boot event.
sb="$(make_sandbox_home)"
typeset -i n
for n in 1 2 3 4 5 6; do
    ( run_sandbox_zsh "$sb" 'print -r -- M_END' > "$T_SCRATCH/cc$n.out" 2>/dev/null ) &
done
wait
typeset -i completed=0
for n in 1 2 3 4 5 6; do
    grep -q "M_END" "$T_SCRATCH/cc$n.out" && (( completed++ ))
done
assert_eq "$completed" "6" "all 6 concurrent cold boots complete"
errf="$T_SCRATCH/cc-final.err"
out=$(run_sandbox_zsh "$sb" 'print -r -- M_END' 2>"$errf")
assert_contains "$out" "M_END" "boot after concurrent cold boots completes"
assert_eq "$(_boot_noise "$errf")" "" "boot after concurrent cold boots is clean"

t_finish
