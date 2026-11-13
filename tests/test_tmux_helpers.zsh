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

# claude-tmux-state: Claude Code and Codex hooks run the executables in
# agent-hooks.d, then record session state on the hook's own pane
# ($TMUX_PANE), which the window-status marks read back. Every run below
# names a scratch HOME and XDG_CONFIG_HOME, so no installed hook can run.
typeset state="$REPO_ROOT/bin/bin/claude-tmux-state"
typeset statebin="$T_SCRATCH/state-bin"
typeset bare_home="$T_SCRATCH/state-bare"   # no agent-hooks.d at all
typeset hooks_xdg="$T_SCRATCH/state-xdg"    # agent-hooks.d with hooks
typeset hooks_home="$T_SCRATCH/state-home"  # ~/.config is $hooks_xdg
typeset hook_stdin="$T_SCRATCH/state-stdin" # what each hook read
typeset payload="$T_SCRATCH/state-payload.json"
mkdir -p "$bare_home" "$hooks_home" "$hook_stdin"
ln -s "$hooks_xdg" "$hooks_home/.config"
make_stub "$statebin" tmux 'printf "%s\n" "$*" >> "$TMUX_CALL_LOG"'
# Hooks a and b log their arguments, keep their stdin, print the output that
# would block Claude Code, and exit $HOOK_RC. off is not executable.
typeset hook_body='printf "%s %s\n" "${0##*/}" "$*" >> "$TMUX_CALL_LOG"
cat > "$HOOK_STDIN_DIR/${0##*/}"
printf "%s\n" "{\"decision\":\"block\"}"
exit "${HOOK_RC:-0}"'
typeset f=''
for f in a b off; do make_stub "$hooks_xdg/agent-hooks.d" "$f" "$hook_body"; done
chmod -x "$hooks_xdg/agent-hooks.d/off"
# The blank last line would not survive a bare command substitution.
printf '%s\n\n' '{"hook_event_name":"UserPromptSubmit","session_id":"s1"}' > "$payload"

# state_hook <home> <xdg|''> <state> [agent]: the hook on pane %7, with
# XDG_CONFIG_HOME unset when <xdg> is empty.
state_hook() {
    local home=$1 xdg=$2
    shift 2
    HOME="$home" TMUX_PANE=%7 TMUX_CALL_LOG="$call_log" HOOK_STDIN_DIR="$hook_stdin" \
        PATH="$statebin:$PATH" env -u XDG_CONFIG_HOME ${xdg:+XDG_CONFIG_HOME=$xdg} sh "$state" "$@"
}

: > "$call_log"
state_hook "$bare_home" '' waiting </dev/null
state_hook "$bare_home" '' clear </dev/null
assert_eq "$(<"$call_log")" $'set-option -p -t %7 @claude_state waiting\nset-option -p -t %7 -u @claude_state' \
    "claude-tmux-state without agent-hooks.d sets and clears the mark exactly as before"
: > "$call_log"
state_hook "$hooks_home" "$bare_home" waiting <"$payload" >/dev/null
assert_eq "$(<"$call_log")" 'set-option -p -t %7 @claude_state waiting' \
    "XDG_CONFIG_HOME, when set, replaces ~/.config as the hooks' home"
: > "$call_log"
state_hook "$hooks_home" '' done <"$payload" >/dev/null
assert_eq "$(<"$call_log")" $'a claude done\nb claude done\nset-option -p -t %7 @claude_state done' \
    "without XDG_CONFIG_HOME the hooks come from ~/.config/agent-hooks.d"

typeset hook_out='' hook_err=''
typeset -i hook_rc
: > "$call_log"
rm -f "$hook_stdin"/*(N)
hook_out=$(state_hook "$bare_home" "$hooks_xdg" done <"$payload" 2>"$T_SCRATCH/state-stderr")
hook_err=$(<"$T_SCRATCH/state-stderr")
assert_eq "$(<"$call_log")" $'a claude done\nb claude done\nset-option -p -t %7 @claude_state done' \
    "each executable in agent-hooks.d runs as <hook> claude <state>, then the mark is set"
if cmp -s "$payload" "$hook_stdin/a" && cmp -s "$payload" "$hook_stdin/b"; then
    t_pass "every hook reads the whole payload on stdin"
else
    t_fail "every hook reads the whole payload on stdin" \
        "a: ${(qq)$(<"$hook_stdin/a")}, b: ${(qq)$(<"$hook_stdin/b")}"
fi
assert_eq "$hook_out" "" "the hooks' stdout never reaches the agent"
assert_eq "$hook_err" "" "a non-executable file in agent-hooks.d is skipped, not tried"
: > "$call_log"
state_hook "$bare_home" "$hooks_xdg" working codex <"$payload" >/dev/null
assert_eq "$(<"$call_log")" $'a codex working\nb codex working\nset-option -p -t %7 @claude_state working' \
    "the second argument names the agent to the hooks"
: > "$call_log"
state_hook "$bare_home" "$hooks_xdg" - <"$payload" >/dev/null
assert_eq "$(<"$call_log")" $'a claude -\nb claude -' \
    "state - runs the hooks but leaves the mark alone"
: > "$call_log"
HOOK_RC=2 state_hook "$bare_home" "$hooks_xdg" waiting <"$payload" >/dev/null
hook_rc=$?
assert_eq "$hook_rc" "0" "a hook that exits 2 (block) does not fail the agent's hook"
assert_eq "$(<"$call_log")" $'a claude waiting\nb claude waiting\nset-option -p -t %7 @claude_state waiting' \
    "a failing hook stops neither the next hook nor the mark"
: > "$call_log"
HOME="$hooks_home" XDG_CONFIG_HOME="$hooks_xdg" TMUX_PANE= TMUX_CALL_LOG="$call_log" \
    HOOK_STDIN_DIR="$hook_stdin" PATH="$statebin:$PATH" sh "$state" done <"$payload"
assert_eq "$(<"$call_log")" "" "claude-tmux-state runs neither the hooks nor tmux outside tmux"

# The hook wiring: every event that runs claude-tmux-state, the state it sets
# (- for the events that only feed the hooks: quota auto-resume notices, each
# Bash call, Codex's async PostModelRequest) and, for Codex, the agent it
# names to the hooks (Claude Code's is the default).
hook_wiring() {
    python3 -I - "$1" <<'PY'
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
}
if have python3; then
    # Notification stays matched to prompts that wait on you: idle_prompt
    # would turn every finished session back into "waiting" after a minute.
    assert_eq "$(hook_wiring "$REPO_ROOT/configs/claude/settings.json")" $'Notification[permission_prompt|elicitation_dialog|elicitation_url_dialog] waiting\nNotification[quota_auto_resume_fired|quota_auto_resume_stale|quota_auto_resume_disabled] -\nPermissionRequest waiting\nPostToolUse working\nPostToolUseFailure working\nPreToolUse[Bash] -\nSessionEnd clear\nStop done\nStopFailure done\nUserPromptSubmit working' \
        "Claude Code hooks drive the tmux state marks"
    assert_eq "$(hook_wiring "$REPO_ROOT/configs/codex/hooks.json")" $'Interrupt done codex\nPermissionRequest waiting codex\nPostModelRequest - codex\nPostToolUse working codex\nSessionEnd clear codex\nStop done codex\nUserPromptSubmit working codex' \
        "Codex hooks drive the tmux state marks and name their agent"
else
    t_skip "Claude Code hooks drive the tmux state marks" "python3 not in PATH"
    t_skip "Codex hooks drive the tmux state marks and name their agent" "python3 not in PATH"
fi

t_finish
