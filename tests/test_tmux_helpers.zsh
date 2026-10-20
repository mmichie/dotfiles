#!/usr/bin/env zsh
# Unit tests for the user-authored helpers invoked by tmux popups/bindings.

source "${0:A:h}/lib.zsh"

typeset sessionizer="$REPO_ROOT/bin/bin/tmux-sessionizer"
typeset stubdir="$T_SCRATCH/sessionizer-bin"
typeset call_log="$T_SCRATCH/tmux-calls.log"

# The scripts are run through `bash` rather than executed: their shebang is
# #!/usr/bin/env bash, and the Linux nix build sandbox has no /usr/bin/env, so
# executing them there failed silently and left every assertion below empty
# (the flake check was red on x86_64-linux for weeks while the same file
# passed on darwin, whose relaxed sandbox exposes /usr/bin). The behavior
# under test is the scripts', not the kernel's shebang resolution.

# `pgrep tmux` used to decide whether switch-client was legal. Simulate an
# existing server while the caller itself is outside tmux; switch-client has
# no client in that situation and must be attach-session instead.
make_stub "$stubdir" pgrep 'printf "%s\n" 123'
make_stub "$stubdir" tmux 'printf "%s\n" "$*" >> "$TMUX_CALL_LOG"
case "$1" in
    has-session) exit "${FAKE_HAS_SESSION_RC:-0}" ;;
    *) exit 0 ;;
esac'

typeset project="$T_SCRATCH/projects/example"
mkdir -p "$project"
: > "$call_log"
TMUX= FAKE_HAS_SESSION_RC=0 TMUX_CALL_LOG="$call_log" \
    PATH="$stubdir:$PATH" bash "$sessionizer" "$project"
typeset calls="$(<"$call_log")"
assert_contains "$calls" "attach-session -t" \
    "sessionizer attaches when called outside tmux with an existing server"
assert_not_contains "$calls" "switch-client" \
    "sessionizer never switch-client outside tmux"

# Two project roots may share a basename. Their tmux session identifiers must
# not collide or selecting the second silently opens the first project.
typeset project_a="$T_SCRATCH/src/api"
typeset project_b="$T_SCRATCH/work/api"
mkdir -p "$project_a" "$project_b"
: > "$call_log"
TMUX=fake FAKE_HAS_SESSION_RC=0 TMUX_CALL_LOG="$call_log" \
    PATH="$stubdir:$PATH" bash "$sessionizer" "$project_a"
TMUX=fake FAKE_HAS_SESSION_RC=0 TMUX_CALL_LOG="$call_log" \
    PATH="$stubdir:$PATH" bash "$sessionizer" "$project_b"
typeset -a switch_targets
switch_targets=(${(f)"$(sed -n 's/^switch-client -t //p' "$call_log")"})
if (( ${#switch_targets} == 2 )) && [[ "$switch_targets[1]" != "$switch_targets[2]" ]]; then
    t_pass "sessionizer gives same-basename projects distinct session names"
else
    t_fail "sessionizer gives same-basename projects distinct session names" \
        "targets: ${(j:, :)switch_targets}"
fi

# tmux-cht's command branch used an unquoted positional expansion. A query
# containing spaces reached curl as a second URL instead of one `+`-joined URL.
typeset cht="$REPO_ROOT/bin/bin/tmux-cht.sh"
typeset chtbin="$T_SCRATCH/cht-bin"
typeset chthome="$T_SCRATCH/cht-home"
typeset curl_log="$T_SCRATCH/curl-args.log"
mkdir -p "$chthome"
: > "$chthome/.tmux-cht-languages"
print -r -- git > "$chthome/.tmux-cht-command"
make_stub "$chtbin" fzf 'printf "%s\n" "$FZF_SELECTION"'
make_stub "$chtbin" curl 'printf "<%s>" "$@" > "$CURL_ARG_LOG"'
make_stub "$chtbin" less 'cat >/dev/null'
make_stub "$chtbin" tmux 'if [ "$1" = neww ]; then
    shift
    exec "$@"
fi
exit 64'
print -r -- "log pretty" | HOME="$chthome" FZF_SELECTION=git \
    CURL_ARG_LOG="$curl_log" PATH="$chtbin:$PATH" bash "$cht" >/dev/null
assert_eq "$(<"$curl_log")" "<-s><--><cht.sh/git~log+pretty>" \
    "tmux-cht sends a multiword command query as one URL"

# claude-tmux-state: Claude Code hooks record session state on the hook's own
# pane ($TMUX_PANE), which the window-status marks read back.
typeset state="$REPO_ROOT/bin/bin/claude-tmux-state"
typeset statebin="$T_SCRATCH/state-bin"
make_stub "$statebin" tmux 'printf "%s\n" "$*" >> "$TMUX_CALL_LOG"'
: > "$call_log"
TMUX_PANE=%7 TMUX_CALL_LOG="$call_log" PATH="$statebin:$PATH" sh "$state" waiting
TMUX_PANE=%7 TMUX_CALL_LOG="$call_log" PATH="$statebin:$PATH" sh "$state" clear
assert_eq "$(<"$call_log")" $'set-option -p -t %7 @claude_state waiting\nset-option -p -t %7 -u @claude_state' \
    "claude-tmux-state sets and clears the state on its own pane"
: > "$call_log"
TMUX_PANE= TMUX_CALL_LOG="$call_log" PATH="$statebin:$PATH" sh "$state" done
assert_eq "$(<"$call_log")" "" "claude-tmux-state does nothing outside tmux"

# The hook wiring: every event that drives the marks, and the state it sets.
if have python3; then
    typeset wiring=''
    wiring=$(python3 -I - "$REPO_ROOT/configs/claude/settings.json" <<'PY'
import json, sys
settings = json.load(open(sys.argv[1]))
for event, groups in sorted(settings.get("hooks", {}).items()):
    for group in groups:
        for hook in group["hooks"]:
            words = hook.get("command", "").split()
            if words and words[0] == "~/bin/claude-tmux-state":
                matcher = group.get("matcher", "")
                print(event + (f"[{matcher}]" if matcher else ""), *words[1:])
PY
)
    # Notification stays matched to prompts that wait on you: idle_prompt
    # would turn every finished session back into "waiting" after a minute.
    assert_eq "$wiring" $'Notification[permission_prompt|elicitation_dialog|elicitation_url_dialog] waiting\nPermissionRequest waiting\nPostToolUse working\nPostToolUseFailure working\nSessionEnd clear\nStop done\nStopFailure done\nUserPromptSubmit working' \
        "Claude Code hooks drive the tmux state marks"
else
    t_skip "Claude Code hooks drive the tmux state marks" "python3 not in PATH"
fi

t_finish
