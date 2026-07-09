#!/usr/bin/env zsh
# Hermetic interactive-startup smoke test: a sandboxed `zsh -i` must boot the
# full module chain cleanly and leave the expected state behind.

source "${0:A:h}/lib.zsh"

typeset sb errf out
sb="$(make_sandbox_home)"
errf="$T_SCRATCH/startup.err"

typeset probe='
print -r -- "M_PATH1=${path[1]}"
[[ -o extended_glob ]]         && print -r -- "M_EXTENDED_GLOB=on"
[[ -o share_history ]]         && print -r -- "M_SHARE_HISTORY=on"
[[ -o interactive_comments ]]  && print -r -- "M_INT_COMMENTS=on"
[[ -o glob_dots ]]             || print -r -- "M_GLOB_DOTS=off"
print -r -- "M_HISTSIZE=$HISTSIZE"
[[ ${(t)HISTFILE} != *export* ]]   && print -r -- "M_HISTFILE_UNEXPORTED=yes"
print -r -- "M_LL_ALIAS=${+aliases[ll]}"
print -r -- "M_EXTRACT=$(whence -w extract)"
print -r -- "M_CORRECT_IGNORE=$CORRECT_IGNORE"
[[ -s "$HOME/.cache/zsh/.zcompdump" ]] && print -r -- "M_COMPDUMP=yes"
print -r -- "M_END"
'

out=$(run_sandbox_zsh "$sb" "$probe" 2>"$errf")

assert_contains "$out" "M_END"                      "interactive startup completes"
assert_contains "$out" "M_PATH1=$sb/bin"            "\$HOME/bin is PATH head"
assert_contains "$out" "M_EXTENDED_GLOB=on"         "EXTENDED_GLOB set"
assert_contains "$out" "M_SHARE_HISTORY=on"         "SHARE_HISTORY set"
assert_contains "$out" "M_INT_COMMENTS=on"          "INTERACTIVE_COMMENTS set"
assert_contains "$out" "M_GLOB_DOTS=off"            "GLOB_DOTS not set (bare * must exclude dotfiles)"
assert_contains "$out" "M_HISTSIZE=600000"          "history sizing applied"
assert_contains "$out" "M_HISTFILE_UNEXPORTED=yes"  "HISTFILE not exported (bash children would write bash-format history into it)"
assert_contains "$out" "M_LL_ALIAS=1"               "aliases defined"
assert_contains "$out" "M_EXTRACT=extract: function" "functions dir autoloaded"
assert_contains "$out" "M_CORRECT_IGNORE=(.*|claude)" "CORRECT_IGNORE set"
assert_contains "$out" "M_COMPDUMP=yes"             "compinit dump written to cache dir"

# stderr must be empty apart from the known no-tty ZLE lines that cached
# tool inits emit when stdin is not a terminal.
typeset -a noise
noise=(${(f)"$(<$errf)"})
noise=(${noise:#*can?t change option: zle*})
if (( ${#noise} == 0 )); then
    t_pass "startup stderr clean"
else
    t_fail "startup stderr clean" "${(j: | :)noise}"
fi

# Second boot of the same sandbox: warm caches (compinit dump, tool inits)
# must source cleanly too. This boot once caught a real bug: a manual
# `source /etc/zshrc` in .zshrc re-ran nix-darwin's bare compinit, which
# prompts (and aborts) when there is no tty.
out=$(run_sandbox_zsh "$sb" 'print -r -- "M_END"' 2>"$errf")
assert_contains "$out" "M_END" "warm-cache startup completes"
noise=(${(f)"$(<$errf)"})
noise=(${noise:#*can?t change option: zle*})
if (( ${#noise} == 0 )); then
    t_pass "warm-cache startup stderr clean"
else
    t_fail "warm-cache startup stderr clean" "${(j: | :)noise}"
fi

# ── Reload: `source ~/.zshrc` must actually reload, idempotently ─────
# This is the documented reload path (CLAUDE.md). A re-source guard used to
# make it a silent no-op; now every module must tolerate repeat sourcing:
# no duplicate fpath entries (would churn the compinit fingerprint), no
# duplicate hook registrations, no readonly collisions, clean stderr.
out=$(run_sandbox_zsh "$sb" '
source ~/.zshrc
source ~/.zshrc
print -r -- "M_RELOAD=ok"
print -r -- "M_FPATH_DUPES=$(( ${#fpath} - ${#${(@u)fpath}} ))"
print -r -- "M_PREEXEC_DUPES=$(( ${#preexec_functions} - ${#${(@u)preexec_functions}} ))"
print -r -- "M_PRECMD_DUPES=$(( ${#precmd_functions} - ${#${(@u)precmd_functions}} ))"
' 2>"$errf")
assert_contains "$out" "M_RELOAD=ok"        "source ~/.zshrc twice completes"
assert_contains "$out" "M_FPATH_DUPES=0"    "reload leaves no duplicate fpath entries"
assert_contains "$out" "M_PREEXEC_DUPES=0"  "reload leaves no duplicate preexec hooks"
assert_contains "$out" "M_PRECMD_DUPES=0"   "reload leaves no duplicate precmd hooks"
noise=(${(f)"$(<$errf)"})
noise=(${noise:#*can?t change option: zle*})
if (( ${#noise} == 0 )); then
    t_pass "reload stderr clean"
else
    t_fail "reload stderr clean" "${(j: | :)noise}"
fi

# ── Banner stamp: shown at most once per interval ────────────────────
# Needs gum (the banner gate); skipped on minimal environments. INFLUX_SHOWN
# is filtered from the env vector rather than overridden — macOS env(1)
# serves the FIRST of duplicate bindings, so appending INFLUX_SHOWN= would
# silently lose.
if have gum; then
    typeset sb2 out2
    sb2="$(make_sandbox_home)"
    _sandbox_env_args "$sb2"
    reply=(${reply:#INFLUX_SHOWN=*})
    out2=$(env -i "${reply[@]}" zsh --no-globalrcs -i -c \
        'print -r -- "STAMP_AT_EXIT=$([[ -f $HOME/.cache/zsh/banner-stamp ]] && print -rn yes || print -rn no)"' \
        2>"$T_SCRATCH/banner.err" </dev/null)
    assert_contains "$out2" "Daily Tip" "banner+tip shown on first shell"
    assert_contains "$out2" "STAMP_AT_EXIT=yes" "stamp exists inside the boot that wrote it"
    if [[ -f "$sb2/.cache/zsh/banner-stamp" ]]; then
        t_pass "banner stamp written"
    else
        t_fail "banner stamp written" "missing; cache dir: [$(ls -A $sb2/.cache/zsh 2>&1 | tr '\n' ' ')] stderr: [$(<$T_SCRATCH/banner.err)]"
    fi
    out2=$(env -i "${reply[@]}" zsh --no-globalrcs -i -c exit 2>/dev/null </dev/null)
    assert_not_contains "$out2" "Daily Tip" "banner suppressed while stamp is fresh"
    touch -t 200001010000 "$sb2/.cache/zsh/banner-stamp"
    out2=$(env -i "${reply[@]}" zsh --no-globalrcs -i -c exit 2>/dev/null </dev/null)
    assert_contains "$out2" "Daily Tip" "banner returns after stamp expires"
else
    t_skip "banner stamp behavior" "gum not in PATH"
fi

t_finish
