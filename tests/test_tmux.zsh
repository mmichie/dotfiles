#!/usr/bin/env zsh
# tmux config tests: boot real servers on isolated sockets against a sandbox
# HOME (empty resurrect state, so continuum's auto-restore is a no-op) and
# assert on parse cleanliness, option state, bindings, hooks, and the
# zsh<->tmux title-protocol surface. The double-source assertion pins the
# update-environment accumulation bug found on the live server (29 entries).

source "${0:A:h}/lib.zsh"

if ! have tmux; then
    t_skip "tmux config" "tmux not in PATH (PATH=${PATH:0:250})"
    t_finish
fi

typeset TMUX_CONF="$REPO_ROOT/configs/tmux/tmux.conf"
typeset SOCK="tmuxtest-$$"
typeset SOCK2="tmuxtest2-$$"

# Sandbox HOME: ~/.config/tmux must resolve for source-file/tpm paths.
typeset thome
thome="$(mktemp -d "$T_SCRATCH/tmuxhome.XXXXXX")"
mkdir -p "$thome/.config"
ln -s "$REPO_ROOT/configs/tmux" "$thome/.config/tmux"

# Kill test servers on any exit; keep lib.zsh's scratch cleanup.
trap 'tmux -L "$SOCK" kill-server 2>/dev/null; tmux -L "$SOCK2" kill-server 2>/dev/null; rm -rf "$T_SCRATCH"' EXIT

tm() { tmux -L "$SOCK" "$@"; }

# ── Boot: parse gate ─────────────────────────────────────────────────
# TMUX_LEVEL= explicitly: the test runner may itself live inside a tmux
# session (TMUX_LEVEL=1 inherited), which would flip this "outer" server
# into the nested %if branch.
typeset boot_err
boot_err=$(HOME="$thome" TMUX_LEVEL= tmux -L "$SOCK" -f "$TMUX_CONF" new-session -d -x 80 -y 24 2>&1)
if [[ $? -eq 0 && -z "$boot_err" ]]; then
    t_pass "config parses with no errors"
else
    t_fail "config parses with no errors" "$boot_err"
fi
tm run-shell true 2>/dev/null   # sync barrier: queue behind tpm's run-shell

# Config errors (failed source-file, nonzero run-shell exits) are queued to
# the server message log, NOT the booting client's stderr — the boot_err
# gate above cannot see them. The log also records routine client commands,
# so match error shapes only.
typeset srvmsgs
# tpm probes TMUX_PLUGIN_MANAGER_PATH before first setting it — benign.
srvmsgs=$(tm show-messages 2>/dev/null \
    | grep -v "unknown variable: TMUX_PLUGIN_MANAGER_PATH" \
    | grep -iE "no such file|returned [1-9]|error|failed|unknown" | head -3)
if [[ -z "$srvmsgs" ]]; then
    t_pass "no errors in server message log after boot"
else
    t_fail "no errors in server message log after boot" "$srvmsgs"
fi

# ── Core options ─────────────────────────────────────────────────────
assert_eq "$(tm show -gv prefix)"            "C-o"  "prefix is C-o"
assert_eq "$(tm show -gv allow-passthrough)" "on"   "allow-passthrough on (chevron banner)"
assert_eq "$(tm show -gv set-titles)"        "on"   "terminal titles enabled"
assert_eq "$(tm show -gv renumber-windows)"  "on"   "windows renumber on close"
assert_eq "$(tm show -gsv escape-time)"      "10"   "escape-time 10ms"
assert_eq "$(tm show -gwv mode-keys)"        "vi"   "vi copy mode"
assert_eq "$(tm show -gsv set-clipboard)"    "on"   "OSC52 clipboard enabled (set-clipboard on)"

# ── update-environment: idempotent across reloads (regression) ───────
typeset -i env1 env2
env1=$(tm show -g update-environment | wc -l)
tm source-file "$TMUX_CONF" 2>/dev/null
tm run-shell true 2>/dev/null
env2=$(tm show -g update-environment | wc -l)
assert_eq "$env2" "$env1" "update-environment does not grow across config reloads"
typeset envlist
envlist=$(tm show -g update-environment)
assert_contains "$envlist" "CHEVRON_WEATHER_LOCATION_CMD" "chevron weather var forwarded"
assert_contains "$envlist" "PATH"                         "PATH forwarded"
assert_contains "$envlist" "SSH_AUTH_SOCK"                "default entries retained after reset"

# ── Title protocol (zsh<->tmux contract) ─────────────────────────────
# tmux 3.6 quirk: a bare `show-hooks -g` does not list set hooks — they
# must be queried by name (hooks are arrays; entries show as name[0]).
assert_contains "$(tm show-hooks -g pane-focus-in)" "pane-focus-in[0]" \
    "pane-focus-in title hook installed"
assert_contains "$(tm show-hooks -g pane-exited)" "pane-exited[0]" \
    "dwm pane-exited layout hook installed"
typeset arf
arf=$(tm show -gv automatic-rename-format)
assert_contains "$arf" "@priority_title" "rename format consumes @priority_title"
assert_contains "$arf" "@dir_title"      "rename format consumes @dir_title"
# Stale-title regression: at a shell prompt the focus hook must prefer
# @dir_title over a leftover @custom_title from an exited command.
typeset fhook
fhook=$(tm show-hooks -g pane-focus-in)
typeset dir_pos custom_pos
dir_pos=${fhook[(i)@dir_title]}
custom_pos=${fhook[(i)@custom_title]}
if (( dir_pos < custom_pos )); then
    t_pass "focus hook checks @dir_title before @custom_title (stale-title regression)"
else
    t_fail "focus hook checks @dir_title before @custom_title (stale-title regression)" \
        "dir@$dir_pos custom@$custom_pos"
fi

# ── Plugins: declared implies vendored, and yank owns drag-copy ──────
typeset -a declared missing
declared=(${(f)"$(grep -E "^set -g @plugin" "$TMUX_CONF" | sed -E "s/.*'[^/]+\/([^']+)'.*/\1/")"})
missing=()
typeset p
for p in "${declared[@]}"; do
    [[ "$p" == tpm ]] && continue
    [[ -d "$REPO_ROOT/configs/tmux/plugins/$p" ]] || missing+=("$p")
done
if (( ${#missing} == 0 )); then
    t_pass "every declared @plugin is vendored (${#declared} declared)"
else
    t_fail "every declared @plugin is vendored" "missing: ${(j:, :)missing}"
fi
typeset dragbind
dragbind=$(tm list-keys -T copy-mode-vi 2>/dev/null | grep MouseDragEnd1Pane | head -1)
if [[ -n "$dragbind" ]]; then
    t_pass "mouse drag-copy bound (tmux-yank)"
else
    t_fail "mouse drag-copy bound (tmux-yank)" "no MouseDragEnd1Pane binding"
fi

# ── Status line: no junk #() commands ────────────────────────────────
typeset sleft
sleft=$(tm show -gv status-left)
assert_not_contains "$sleft" '#( ' "status-left has no broken #() command (regression)"

# ── Keybindings: dwm + nested toggle ─────────────────────────────────
typeset rootkeys offkeys
rootkeys=$(tm list-keys -T root 2>/dev/null)
offkeys=$(tm list-keys -T off 2>/dev/null)
assert_contains "$rootkeys" "M-n" "dwm newpane binding present"
assert_contains "$rootkeys" '"M-;"' "nested-toggle binding in root table"
assert_contains "$offkeys"  '"M-;"' "nested-toggle binding in off table"
typeset prefixkeys
prefixkeys=$(tm list-keys -T prefix 2>/dev/null)
assert_contains "$prefixkeys" "confirm-before" "kill-window asks for confirmation"
assert_contains "$prefixkeys" "display-popup" "prefix-f sessionizer opens in a popup (TTY for fzf)"
# prefix-P/Y use pbpaste/pbcopy, guarded behind `if-shell uname = Darwin` in
# tmux.conf — present on macOS, absent on Linux. CI runs this suite on both.
if [[ "$(uname)" == Darwin ]]; then
    assert_contains "$prefixkeys" "pbpaste" "prefix-P/Y clipboard binds present on macOS"
else
    assert_not_contains "$prefixkeys" "pbpaste" "prefix-P/Y clipboard binds guarded off on Linux"
fi

# ── Nested branch: %if TMUX_LEVEL styles with orange accent ──────────
typeset boot2_err
boot2_err=$(HOME="$thome" TMUX_LEVEL=1 tmux -L "$SOCK2" -f "$TMUX_CONF" new-session -d -x 80 -y 24 2>&1)
if [[ $? -eq 0 && -z "$boot2_err" ]]; then
    t_pass "nested config branch parses"
else
    t_fail "nested config branch parses" "$boot2_err"
fi
assert_contains "$(tmux -L "$SOCK2" show -gwv window-status-current-style 2>/dev/null)" \
    "colour208" "nested server uses orange accent"
assert_contains "$(tm show -gwv window-status-current-style)" \
    "colour39" "outer server uses blue accent"

tm kill-server 2>/dev/null
tmux -L "$SOCK2" kill-server 2>/dev/null

t_finish
