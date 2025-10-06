#!/bin/zsh

# Claude wrapper function to prevent shell exit
claude() {
    # Set tmux window name if in tmux
    if [[ -n "$TMUX" ]]; then
        tmux rename-window "🤖 $(basename "$PWD")"
    fi

    # Set terminal title for Ghostty
    echo -ne "\033]0;claude\007"

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
        return 1
    fi
    
    # Run claude with proper directory and shell protection
    # Use 'command' to bypass any functions/aliases
    (
        cd "$current_dir"
        # Trap EXIT to prevent shell from exiting
        trap 'exit 0' EXIT
        command "$claude_cmd" "$@"
    )
    local exit_code=$?

    # Re-enable tmux automatic rename if in tmux
    if [[ -n "$TMUX" ]]; then
        tmux set-window-option automatic-rename on
    fi

    # Reset terminal title to zsh
    echo -ne "\033]0;zsh\007"

    return $exit_code
}