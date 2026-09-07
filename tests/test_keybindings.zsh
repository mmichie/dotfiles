#!/usr/bin/env zsh
# Keybinding assertions against a fully-initialized interactive shell.
#
# Regression: prefix history search was bound to bare ^[A / ^[B (ESC+letter),
# which no terminal emits for arrows — real arrows send CSI ^[[A or SS3 ^[OA.

source "${0:A:h}/lib.zsh"

typeset sb='' out=''
sb="$(make_sandbox_home)"
out=$(run_sandbox_zsh "$sb" 'bindkey -M viins' 2>/dev/null)

assert_contains "$out" '"^[[A" up-line-or-beginning-search'   "Up (CSI) bound to prefix history search"
assert_contains "$out" '"^[OA" up-line-or-beginning-search'   "Up (SS3) bound to prefix history search"
assert_contains "$out" '"^[[B" down-line-or-beginning-search' "Down (CSI) bound to prefix history search"
assert_contains "$out" '"^[OB" down-line-or-beginning-search' "Down (SS3) bound to prefix history search"
assert_not_contains "$out" '"^[A" up-line-or-beginning-search' "bare ESC-A not bound (regression)"

assert_contains "$out" '"^A" beginning-of-line'    "^A bound"
assert_contains "$out" '"^E" end-of-line'          "^E bound"
assert_contains "$out" '"^X^E" edit-command-line'  "^X^E opens \$EDITOR"

# Main keymap is vi insert mode
out=$(run_sandbox_zsh "$sb" 'bindkey -lL main' 2>/dev/null)
assert_contains "$out" "viins" "main keymap is viins"

# fzf-dependent bindings — gate on fzf as seen from *inside* the sandbox
# shell (the runner's view can differ, e.g. under nix builds).
# Startup notices are legitimate stdout; use exit status for the capability
# probe so SSH-agent messages cannot silently skip these assertions.
if run_sandbox_zsh "$sb" '(( $+commands[fzf] ))' >/dev/null 2>&1; then
    out=$(run_sandbox_zsh "$sb" 'bindkey -M viins "^R"; bindkey -M vicmd "^R"; bindkey -M viins "^T"' 2>/dev/null)
    assert_contains "$out" '"^R" atuin-fzf-history' "viins ^R is atuin-fzf-history"
    assert_contains "$out" '"^R" redo'              "vicmd ^R restored to redo"
    assert_contains "$out" '"^T" fzf-file-widget'   "viins ^T is fzf file widget"
else
    t_skip "fzf bindings" "fzf not visible in sandbox"
fi

# Pin the noisy-startup case even on hosts where a real agent is available.
typeset noisy="$(make_sandbox_home)"
make_stub "$noisy/tools" fzf
print -r -- 'path=("$HOME/tools" $path); print -r -- "Starting new SSH agent..."' > "$noisy/.zshrc.early.local"
if run_sandbox_zsh "$noisy" '(( $+commands[fzf] ))' >/dev/null 2>&1; then
    t_pass "fzf capability probe tolerates startup stdout"
else
    t_fail "fzf capability probe tolerates startup stdout"
fi

t_finish
