#!/usr/bin/env zsh
# Unit tests for the user-authored helpers invoked by tmux popups/bindings.

source "${0:A:h}/lib.zsh"

typeset sessionizer="$REPO_ROOT/bin/bin/tmux-sessionizer"
typeset stubdir="$T_SCRATCH/sessionizer-bin"
typeset call_log="$T_SCRATCH/tmux-calls.log"

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
    PATH="$stubdir:$PATH" "$sessionizer" "$project"
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
    PATH="$stubdir:$PATH" "$sessionizer" "$project_a"
TMUX=fake FAKE_HAS_SESSION_RC=0 TMUX_CALL_LOG="$call_log" \
    PATH="$stubdir:$PATH" "$sessionizer" "$project_b"
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
    CURL_ARG_LOG="$curl_log" PATH="$chtbin:$PATH" "$cht" >/dev/null
assert_eq "$(<"$curl_log")" "<-s><--><cht.sh/git~log+pretty>" \
    "tmux-cht sends a multiword command query as one URL"

t_finish
