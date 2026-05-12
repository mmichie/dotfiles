#!/bin/zsh

# Third-party shell integrations: atuin, direnv, vivid, zoxide, work profile.

setup_integrations() {
    # Work profile (machine-specific env, not in dotfiles repo)
    [[ -f "$HOME/.bash_work_profile" ]] && source "$HOME/.bash_work_profile"

    # Atuin shell history. Its ^R binding is disabled here; we override with
    # the atuin-fzf-history widget bound below.
    command -v atuin  &>/dev/null && eval "$(atuin init zsh --disable-up-arrow --disable-ctrl-r)"

    # Direnv per-directory environment
    command -v direnv &>/dev/null && eval "$(direnv hook zsh)"

    # Vivid ls colors
    command -v vivid  &>/dev/null && export LS_COLORS="$(vivid generate tokyonight-night)"
}

# zoxide smart directory navigation. ztop helper lives as an autoloaded
# function in $SHELL_FUNCTIONS_DIR.
setup_zoxide() {
    command -v zoxide &>/dev/null || return
    eval "$(zoxide init zsh)"
    export _ZO_ECHO=1                                                  # Print matched dir before cd
    export _ZO_RESOLVE_SYMLINKS=1                                      # Resolve symlinks to true path
    export _ZO_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zoxide"
    alias cdi="zi"                                                     # Interactive directory selection
}

# Register atuin-fzf-history as a ZLE widget. The function body is autoloaded
# from $SHELL_FUNCTIONS_DIR on first ^R press. Binding the widget requires
# `zle -N` to know the name — the function need not exist yet.
zle -N atuin-fzf-history
if command -v fzf &>/dev/null; then
    bindkey -M viins '^R' atuin-fzf-history
    # fzf's `source <(fzf --zsh)` in 45-keybindings.zsh also bound vicmd ^R
    # to fzf-history-widget; restore vi's redo there.
    bindkey -M vicmd '^R' redo
fi

setup_integrations
setup_zoxide
