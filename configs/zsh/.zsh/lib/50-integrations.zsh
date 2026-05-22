#!/bin/zsh

# Third-party shell integrations: atuin, direnv, vivid, zoxide, work profile.
#
# Slow `tool init` / `tool generate` commands are cached to disk and
# re-run only when the tool's binary (or its config) is newer than the
# cache. `eval $(tool init zsh)` ran ~50-100ms per shell; sourcing a
# cached file is closer to 1ms.

# Re-run `cmd` and write its output to $cache_path when any of
# $invalidators... is newer than the cache. Otherwise leave it alone.
_refresh_cache() {
    local cache_path="$1"
    shift
    local cmd="$1"
    shift
    local inv
    if [[ ! -f $cache_path ]]; then
        eval "$cmd" > "$cache_path"
        return
    fi
    for inv in "$@"; do
        [[ -e $inv && $inv -nt $cache_path ]] || continue
        eval "$cmd" > "$cache_path"
        return
    done
}

setup_integrations() {
    # Work profile (machine-specific env, not in dotfiles repo)
    [[ -f "$HOME/.bash_work_profile" ]] && source "$HOME/.bash_work_profile"

    # Atuin shell history. Cached init output; re-sources cleanly. The ^R
    # binding is disabled here — see the atuin-fzf-history widget below.
    if command -v atuin &>/dev/null; then
        local atuin_cache="$SHELL_CACHE_DIR/atuin-init.zsh"
        _refresh_cache "$atuin_cache" \
            'atuin init zsh --disable-up-arrow --disable-ctrl-r' \
            "$(command -v atuin)" \
            "$HOME/.config/atuin/config.toml"
        source "$atuin_cache"
    fi

    # Direnv per-directory environment
    if command -v direnv &>/dev/null; then
        local direnv_cache="$SHELL_CACHE_DIR/direnv-hook.zsh"
        _refresh_cache "$direnv_cache" 'direnv hook zsh' "$(command -v direnv)"
        source "$direnv_cache"
    fi

    # Vivid ls colors. The theme name is baked into vivid's binary, so
    # binary mtime is the only invalidator.
    if command -v vivid &>/dev/null; then
        local vivid_cache="$SHELL_CACHE_DIR/vivid-ls-colors"
        _refresh_cache "$vivid_cache" 'vivid generate tokyonight-night' \
            "$(command -v vivid)"
        export LS_COLORS="$(<$vivid_cache)"
    fi
}

# zoxide smart directory navigation. ztop helper lives as an autoloaded
# function in $SHELL_FUNCTIONS_DIR.
setup_zoxide() {
    command -v zoxide &>/dev/null || return
    local zoxide_cache="$SHELL_CACHE_DIR/zoxide-init.zsh"
    _refresh_cache "$zoxide_cache" 'zoxide init zsh' "$(command -v zoxide)"
    source "$zoxide_cache"
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
