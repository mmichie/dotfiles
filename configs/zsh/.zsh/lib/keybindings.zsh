#!/bin/zsh

# Readline and widget keybindings.
# The atuin-fzf-history widget is registered in integrations.zsh; the fzf
# conditional below overrides the earlier ^R binding when fzf is available.
setup_readline() {
    # Enable vi command mode
    bindkey -v

    # Basic navigation bindings
    bindkey '^A' beginning-of-line
    bindkey '^E' end-of-line
    bindkey '^D' delete-char
    bindkey '^L' clear-screen
    bindkey '^W' backward-kill-word

    # Word navigation (Alt+Left/Right)
    bindkey '^[b' backward-word
    bindkey '^[f' forward-word
    bindkey '^[[1;3D' backward-word   # Alt+Left in most terminals
    bindkey '^[[1;3C' forward-word    # Alt+Right in most terminals

    # History search bindings
    bindkey '^R' history-incremental-search-backward
    bindkey '^[A' up-line-or-search
    bindkey '^[B' down-line-or-search

    # fzf widgets + atuin history search (overrides ^R above)
    if command -v fzf &>/dev/null; then
        bindkey '^R' atuin-fzf-history
        bindkey '^T' fzf-file-widget
        bindkey '^[c' fzf-cd-widget
    fi

    # tmux-sessionizer for quick project switching
    if command -v tmux-sessionizer &>/dev/null; then
        bindkey -s '^F' 'tmux-sessionizer\n'
    fi
}
