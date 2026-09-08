#!/usr/bin/env zsh
source "${0:A:h}/lib.zsh"
typeset inner="$T_SCRATCH/prompt.zsh" out=''
cat > "$inner" <<'EOF'
CHEVRON_DISABLE=1
source "$1/.zsh/lib/60-prompt.zsh"
trace="$2"
HOST=prompt-test
builtin cd -P "$3"
# Observe formatting in the actual hook, including any nested command
# substitutions. Builtin print writes the trace without spawning a process.
printf() {
    builtin print -r -- "$ZSH_SUBSHELL" >> "$trace"
    builtin printf "$@"
}
osc7_cwd > "$4"
EOF
typeset dir="$T_SCRATCH/a café"
mkdir -p "$dir"
zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$T_SCRATCH/trace" "$dir" "$T_SCRATCH/osc7"
typeset -a levels=("${(@f)$(<"$T_SCRATCH/trace")}")
if (( ${#levels} > 0 )) && [[ "${(j::)levels}" != *[^0]* ]]; then
    t_pass "OSC7 formats paths without any command-substitution subshells"
else
    t_fail "OSC7 formats paths without any command-substitution subshells" "levels=${(j:,:)levels}"
fi
assert_eq "$(<"$T_SCRATCH/osc7")" $'\e]7;file://prompt-test'"${T_SCRATCH:A}/a%20caf%C3%A9"$'\a' \
    "OSC7 retains exact terminal escape bytes and UTF-8 percent encoding"
t_finish
