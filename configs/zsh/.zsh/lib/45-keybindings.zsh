#!/bin/zsh

# fzf's shell integration (fzf-file-widget, fzf-cd-widget, history widget)
# is sourced from a cache in 50-integrations.zsh — `source <(fzf --zsh)`
# here cost a fork+exec every shell. bindkey happily binds widget names
# before the widgets exist (resolution happens at keypress), so binding ^T
# and alt-c below works even though fzf's script loads two modules later.

# Prefix-aware history search (zsh built-in widgets). Typing a prefix then
# up/down searches for history entries starting with it.
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search

# edit-command-line widget: opens current buffer in $EDITOR on ^X^E.
autoload -Uz edit-command-line
zle -N edit-command-line

# Readline and widget keybindings. Bind to viins only — vicmd (post-ESC)
# keeps its vi defaults (notably ^R=redo, ^D=list-choices). The atuin-fzf-
# history widget is registered in integrations.zsh.
setup_readline() {
    bindkey -v

    _bind() { bindkey -M viins "$1" "$2"; }

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

    # History search. Up/Down arrows send CSI (^[[A) or SS3 (^[OA, terminal
    # application mode) — bind both. Bare ^[A is ESC+A, which no terminal
    # sends for arrows.
    _bind '^R' history-incremental-search-backward
    _bind '^[[A' up-line-or-beginning-search
    _bind '^[[B' down-line-or-beginning-search
    _bind '^[OA' up-line-or-beginning-search
    _bind '^[OB' down-line-or-beginning-search

    # Edit current command line in $EDITOR
    _bind '^X^E' edit-command-line

    # fzf widgets (^R is rebound to atuin-fzf-history in 50-integrations.zsh
    # after that widget is registered)
    if command -v fzf &>/dev/null; then
        _bind '^T' fzf-file-widget
        _bind '^[c' fzf-cd-widget
    fi

    # tmux-sessionizer for quick project switching (-s = string binding)
    if command -v tmux-sessionizer &>/dev/null; then
        bindkey -M viins -s '^F' 'tmux-sessionizer\n'
    fi

    unfunction _bind
}

setup_readline
