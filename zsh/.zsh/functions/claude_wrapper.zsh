#!/bin/zsh

# Claude wrapper function to prevent shell exit
claude() {
    # Function to cleanup tmux and terminal title
    local cleanup() {
        # Clear custom title marker and window-level priority title
        if [[ -n "$TMUX" ]]; then
            tmux set-option -p @custom_title ""
            tmux set-option -w @priority_title ""
            # Immediately update window title instead of waiting for precmd
            # This ensures title updates even if user is viewing a different pane
            local smart_title=$(_tmux_emoji_get_dir_title 2>/dev/null || echo "$(basename "$PWD")")
            tmux set-option -p @dir_title "$smart_title"
            tmux rename-window "$smart_title"
            tmux set-window-option automatic-rename on
        fi
        # Reset terminal title to zsh
        echo -ne "\033]0;zsh\007"
    }

    # Set terminal title for Ghostty
    echo -ne "\033]0;claude\007"

    # Store custom title in tmux pane option AND window-level priority title (persists across pane switches)
    if [[ -n "$TMUX" ]]; then
        local title="✨ $(basename "$PWD")"
        tmux set-option -p @custom_title "$title"
        tmux set-option -w @priority_title "$title"
        tmux rename-window "$title"
        # Disable automatic-rename to prevent status-interval from overwriting with @dir_title
        tmux set-window-option automatic-rename off
    fi

    # Save current directory
    local current_dir="$PWD"

    # Ensure nvm is loaded
    if ! command -v node >/dev/null 2>&1; then
        # Trigger lazy nvm loading
        if type nvm >/dev/null 2>&1; then
            nvm use default >/dev/null 2>&1
        elif [[ -f "$HOME/.nvm/nvm.sh" ]]; then
            source "$HOME/.nvm/nvm.sh"
        fi
    fi

    # Find claude executable - use command to bypass any aliases/functions
    local claude_cmd=""
    # Use command -v to find the actual binary dynamically
    claude_cmd=$(command -v claude 2>/dev/null)
    if [[ -z "$claude_cmd" ]]; then
        echo "Error: claude command not found" >&2
        print -Pn "\e]0;%~\a"
        cleanup
        return 1
    fi

    # Ensure cleanup happens even on timeout/interrupt
    trap cleanup INT TERM EXIT

    # Run claude with proper directory and shell protection
    # Use 'command' to bypass any functions/aliases
    (
        cd "$current_dir"
        # Trap EXIT to prevent shell from exiting
        trap 'exit 0' EXIT
        command "$claude_cmd" "$@"
    )
    local exit_code=$?

    trap - INT TERM EXIT

    # Always cleanup
    cleanup

    return $exit_code
}