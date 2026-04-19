#!/bin/zsh

# Claude wrapper: pins tmux window title, keeps shell from exiting on claude quirks
claude() {
    local claude_cmd=$(command -v claude 2>/dev/null)
    if [[ -z "$claude_cmd" ]]; then
        echo "Error: claude command not found" >&2
        return 1
    fi

    local pane_id="" window_id=""
    if [[ -n "$TMUX" ]]; then
        pane_id=$(tmux display-message -p '#{pane_id}')
        window_id=$(tmux display-message -p '#{window_id}')
        _tmux_title_push "$pane_id" "$window_id" "✨ $(basename "$PWD")"
    fi

    # Set terminal title for Ghostty (non-tmux path still wants it)
    printf '\033]0;claude\007'

    local cleanup_cmd="printf '\\033]0;zsh\\007'"
    if [[ -n "$TMUX" ]]; then
        cleanup_cmd="_tmux_title_pop '$pane_id' '$window_id'; $cleanup_cmd"
    fi
    trap "$cleanup_cmd" INT TERM EXIT

    # Run claude in a subshell with EXIT trap to keep the outer shell alive
    (
        trap 'exit 0' EXIT
        command "$claude_cmd" "$@"
    )
    local exit_code=$?

    trap - INT TERM EXIT
    [[ -n "$TMUX" ]] && _tmux_title_pop "$pane_id" "$window_id"
    printf '\033]0;zsh\007'

    return $exit_code
}
