#!/bin/zsh

# Third-party shell integrations (atuin, direnv, vivid, work profile).
# Called from .zshrc after init_shell.
setup_integrations() {
    # Work profile (machine-specific env, not in dotfiles repo)
    [[ -f "$HOME/.bash_work_profile" ]] && source "$HOME/.bash_work_profile"

    # Atuin shell history. Disable its bindings — setup_readline binds ^R
    # to the atuin-fzf-history widget defined below.
    if command -v atuin &>/dev/null; then
        eval "$(atuin init zsh --disable-up-arrow --disable-ctrl-r)"
    fi

    # Direnv per-directory environment
    if command -v direnv &>/dev/null; then
        eval "$(direnv hook zsh)"
    fi

    # Vivid ls colors
    if command -v vivid &>/dev/null; then
        export LS_COLORS="$(vivid generate tokyonight-night)"
    fi
}

# Setup zoxide for smart directory navigation
setup_zoxide() {
    if command -v zoxide &>/dev/null; then
        # Initialize zoxide with zsh integration
        eval "$(zoxide init zsh)"

        # Configure zoxide
        export _ZO_ECHO=1            # Print the matched directory before navigating to it
        export _ZO_RESOLVE_SYMLINKS=1 # Resolve symlinked directories to their true path
        export _ZO_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zoxide" # Set data directory

        alias cdi="zi"               # Interactive directory selection

        # Create a function to add current directory with a custom name
        zadd() {
            if [[ $# -eq 0 ]]; then
                echo "Usage: zadd <name> - Add current directory with custom name"
                return 1
            fi
            zoxide add "$(pwd)" --name "$1"
        }

        # Create a function to show top directories
        ztop() {
            local count=${1:-10}
            zoxide query --list | head -n "$count"
        }
    fi
}

# Custom function to search atuin history with fzf
atuin-fzf-history() {
    local selected
    if command -v atuin &>/dev/null; then
        # Use atuin to get history and pipe to fzf
        selected=$(atuin search --cmd-only --limit 10000 2>/dev/null | \
            fzf --height 40% \
                --reverse \
                --tac \
                --no-sort \
                --exact \
                --query="${LBUFFER}" \
                --preview 'echo {}' \
                --preview-window down:3:wrap \
                --bind 'ctrl-y:execute-silent(echo -n {} | pbcopy)+abort' \
                --header 'Press CTRL-Y to copy command to clipboard')
    else
        # Fallback to regular fzf history if atuin is not available
        selected=$(fc -rl 1 | \
            fzf --height 40% \
                --reverse \
                --tac \
                --no-sort \
                --exact \
                --query="${LBUFFER}" \
                --preview 'echo {}' \
                --preview-window down:3:wrap \
                --bind 'ctrl-y:execute-silent(echo -n {2..} | pbcopy)+abort' \
                --header 'Press CTRL-Y to copy command to clipboard' | \
            sed 's/^ *[0-9]* *//')
    fi

    if [[ -n "$selected" ]]; then
        LBUFFER="$selected"
        zle redisplay
    fi
    zle reset-prompt
}

# Create the widget
zle -N atuin-fzf-history
