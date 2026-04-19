#!/bin/zsh

# Helpers for pinning a custom tmux window/pane title around a wrapped command
# (ssh, sudo -i, claude). Callers capture pane_id/window_id at start so cleanup
# targets the correct pane even if the user has since moved focus.
#
# Usage:
#   [[ -n "$TMUX" ]] || return
#   local pane_id=$(tmux display-message -p '#{pane_id}')
#   local window_id=$(tmux display-message -p '#{window_id}')
#   _tmux_title_push "$pane_id" "$window_id" "🔐 myhost"
#   trap "_tmux_title_pop '$pane_id' '$window_id'" INT TERM EXIT
#   ...run command...
#   trap - INT TERM EXIT
#   _tmux_title_pop "$pane_id" "$window_id"

_tmux_title_push() {
    local pane_id="$1" window_id="$2" title="$3"
    tmux set-option -t "$pane_id" -p @custom_title "$title"
    tmux set-option -t "$window_id" -w @priority_title "$title"
    tmux rename-window -t "$window_id" "$title"
    tmux set-window-option -t "$window_id" automatic-rename off
}

_tmux_title_pop() {
    local pane_id="$1" window_id="$2"
    [[ -z "$pane_id" || -z "$window_id" ]] && return
    tmux set-option -t "$pane_id" -p @custom_title ""
    tmux set-option -t "$pane_id" -p @is_root ""
    tmux set-option -t "$window_id" -w @priority_title ""
    local dir_title=$(basename "$PWD")
    tmux set-option -t "$pane_id" -p @dir_title "$dir_title"
    tmux rename-window -t "$window_id" "$dir_title"
    tmux set-window-option -t "$window_id" automatic-rename on
}
