#!/bin/zsh

# Source fzf's shell integration at module load so its widgets (fzf-file-widget,
# fzf-cd-widget) are defined before setup_readline binds to them. fzf also
# binds ^R to its own fzf-history-widget; setup_readline overwrites that with
# atuin-fzf-history, which runs *after* this because init_shell is called from
# .zshrc post-module-load.
if command -v fzf &>/dev/null; then
    source <(fzf --zsh)
fi

# Prefix-aware history search (zsh built-in widgets). Typing a prefix then
# up/down searches for history entries starting with it.
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search

# edit-command-line widget: opens current buffer in $EDITOR on ^X^E.
autoload -Uz edit-command-line
zle -N edit-command-line

# Readline and widget keybindings. After bindkey -v, plain `bindkey` only
# targets viins; vicmd (post-ESC) keeps its vi defaults. We bind to both
# keymaps via a _bind helper so shortcuts work regardless of mode.
# The atuin-fzf-history widget is registered in integrations.zsh.
setup_readline() {
    bindkey -v

    _bind() { bindkey -M viins "$1" "$2"; bindkey -M vicmd "$1" "$2"; }

    # Basic navigation
    _bind '^A' beginning-of-line
    _bind '^E' end-of-line
    _bind '^D' delete-char
    _bind '^L' clear-screen
    _bind '^W' backward-kill-word

    # Word navigation (Alt+Left/Right)
    _bind '^[b' backward-word
    _bind '^[f' forward-word
    _bind '^[[1;3D' backward-word   # Alt+Left in most terminals
    _bind '^[[1;3C' forward-word    # Alt+Right in most terminals

    # History search
    _bind '^R' history-incremental-search-backward
    _bind '^[A' up-line-or-beginning-search
    _bind '^[B' down-line-or-beginning-search

    # Edit current command line in $EDITOR
    _bind '^X^E' edit-command-line

    # fzf widgets + atuin history search (overrides ^R above)
    if command -v fzf &>/dev/null; then
        _bind '^R' atuin-fzf-history
        _bind '^T' fzf-file-widget
        _bind '^[c' fzf-cd-widget
    fi

    # tmux-sessionizer for quick project switching (-s = string binding)
    if command -v tmux-sessionizer &>/dev/null; then
        bindkey -M viins -s '^F' 'tmux-sessionizer\n'
        bindkey -M vicmd -s '^F' 'tmux-sessionizer\n'
    fi

    unfunction _bind
}
