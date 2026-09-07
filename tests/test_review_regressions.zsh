#!/usr/bin/env zsh
# Behavioral regressions from the zshrc review; external tools are stubs.
source "${0:A:h}/lib.zsh"

typeset stubdir="$T_SCRATCH/bin" inner="$T_SCRATCH/probe.zsh" out=''
make_stub "$stubdir" claude 'printf "{\"ok\":true}\n"; exit 7'
cat > "$inner" <<'EOF'
path=("$2" $path)
unset TMUX
fpath=("$1/.zsh/functions" $fpath)
autoload -Uz claude
claude -p --output-format json > "$3"
print -r -- "RC=$?"
EOF
out=$(zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$stubdir" "$T_SCRATCH/output")
assert_eq "$(<"$T_SCRATCH/output")" '{"ok":true}' \
    "redirected claude output contains only the binary's output"
assert_eq "$out" 'RC=7' "claude preserves the binary's failure status"

# Trigger the actual lazy wrapper with a different JDK on PATH. The selected
# JAVA_HOME must reach the build tool, while unset/empty values still infer it.
make_stub "$stubdir" javac
make_stub "$stubdir" mvn 'printf "JH=<%s>\n" "$JAVA_HOME"'
typeset selected="$T_SCRATCH/selected-jdk"
make_stub "$selected/bin" javac
typeset sb="$(make_sandbox_home)"
out=$(run_sandbox_zsh "$sb" '
    path=("$STUBDIR" $path)
    export JAVA_HOME="$SELECTED"
    mvn
' STUBDIR="$stubdir" SELECTED="$selected" 2>/dev/null)
assert_contains "$out" "JH=<$selected>" "first Maven invocation preserves an explicit JAVA_HOME"
for mode in unset empty; do
    out=$(run_sandbox_zsh "$sb" '
        path=("$STUBDIR" $path)
        if [[ "$MODE" == unset ]]; then unset JAVA_HOME; else export JAVA_HOME=""; fi
        mvn
    ' STUBDIR="$stubdir" MODE="$mode" 2>/dev/null)
    assert_contains "$out" "JH=<${T_SCRATCH:A}>" "first Maven invocation infers $mode JAVA_HOME"
done

# Exercise real ZLE BUFFER/LBUFFER/RBUFFER semantics, with deterministic
# history and selection. zle-line-init drives the widget without keystrokes.
cat > "$inner" <<'EOF'
source "$1/.zsh/functions/atuin-fzf-history"
atuin() { print -r -- 'echo selected'; }
fzf() { local line; while IFS= read -r line; do print -r -- "$line"; done; }
probe() {
    BUFFER='ec --old-argument'
    CURSOR=2
    atuin-fzf-history
    result="$BUFFER"
    result_cursor=$CURSOR
    zle .accept-line
}
zle -N zle-line-init probe
result='' result_cursor=0 answer=''
vared answer
print -r -- "RESULT=<$result> CURSOR=$result_cursor"
EOF
if out=$(run_under_pty zsh --no-globalrcs -f "$inner" "$ZSH_CONF"); then
    typeset result_line="${${out##*RESULT=}/$'\n'/}"
    assert_eq "$result_line" '<echo selected> CURSOR=13' \
        "history selection replaces the whole ZLE buffer and moves cursor to end"
else
    t_skip "history selection in ZLE" "PTY unavailable"
fi

t_finish
