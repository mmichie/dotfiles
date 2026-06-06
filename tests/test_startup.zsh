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
print -r -- "M_HISTSIZE=$HISTSIZE"
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
assert_contains "$out" "M_HISTSIZE=600000"          "history sizing applied"
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

t_finish
