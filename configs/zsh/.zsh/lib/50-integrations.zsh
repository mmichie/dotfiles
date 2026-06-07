#!/bin/zsh

# Third-party shell integrations: atuin, direnv, vivid, zoxide, work profile.
#
# Slow `tool init` / `tool generate` commands are cached to disk and
# re-run only when the tool's binary (or its config) is newer than the
# cache. `eval $(tool init zsh)` ran ~50-100ms per shell; sourcing a
# cached file is closer to 1ms.

# Re-run `cmd` and write its output to $cache_path when any of
# $invalidators... is newer than the cache. Otherwise leave it alone.
# Returns nonzero when the cache could not be (re)generated — callers
# should `&& source` so a failed tool init degrades to "tool not set up
# this shell" instead of sourcing garbage.
# Sourceable caches (*.zsh only — data files like vivid-ls-colors are not
# scripts) are zcompiled so later shells load wordcode; a missing .zwc next
# to an existing cache is backfilled once (post-deploy).
_refresh_cache() {
    local cache_path="$1"
    shift
    local cmd="$1"
    shift
    local inv
    if [[ ! -f $cache_path ]]; then
        _write_cache "$cache_path" "$cmd"
        return
    fi
    for inv in "$@"; do
        [[ -e $inv && $inv -nt $cache_path ]] || continue
        _write_cache "$cache_path" "$cmd"
        return
    done
    [[ "$cache_path" == *.zsh && ! -f "$cache_path.zwc" ]] && _zcompile_cache "$cache_path"
    return 0
}

# Atomic: generate into a temp file and mv into place only on success. The
# old truncate-then-write left an empty cache behind a failed or
# interrupted init, and every later shell sourced it forever (the binary
# mtime invalidator never fires again).
_write_cache() {
    local cache_path="$1" cmd="$2"
    local tmp="$cache_path.$$"
    if eval "$cmd" > "$tmp"; then
        command mv -f "$tmp" "$cache_path"
        _zcompile_cache "$cache_path"
    else
        command rm -f "$tmp"
        return 1
    fi
}

_zcompile_cache() {
    [[ "$1" == *.zsh ]] || return 0
    zcompile "$1" 2>/dev/null
}

setup_integrations() {
    # Work profile (machine-specific env, not in dotfiles repo)
    [[ -f "$HOME/.bash_work_profile" ]] && source "$HOME/.bash_work_profile"

    # 1Password shell-plugin aliases (op plugin init <cli> writes these).
    # Routes e.g. aws/cargo through `op plugin run` so creds are injected
    # from the vault at call time instead of living on disk.
    [[ -f "$HOME/.config/op/plugins.sh" ]] && source "$HOME/.config/op/plugins.sh"

    # Invalidator paths come from zsh's $commands hash — $(command -v x)
    # forks a subshell per lookup even though command is a builtin.

    # fzf keybindings/completion. Sourced here (cached) rather than in
    # 45-keybindings: bindkey happily binds widget names before the widgets
    # exist, so only the ^R override order at the bottom of this file
    # matters. fzf's own script binds ^R in viins/vicmd; the override after
    # setup_integrations() puts atuin-fzf-history and redo back on top.
    if command -v fzf &>/dev/null; then
        local fzf_cache="$SHELL_CACHE_DIR/fzf-init.zsh"
        _refresh_cache "$fzf_cache" 'fzf --zsh' "$commands[fzf]" \
            && source "$fzf_cache"
    fi

    # Atuin shell history. Cached init output; re-sources cleanly. The ^R
    # binding is disabled here — see the atuin-fzf-history widget below.
    if command -v atuin &>/dev/null; then
        local atuin_cache="$SHELL_CACHE_DIR/atuin-init.zsh"
        _refresh_cache "$atuin_cache" \
            'atuin init zsh --disable-up-arrow --disable-ctrl-r' \
            "$commands[atuin]" \
            "$HOME/.config/atuin/config.toml" \
            && source "$atuin_cache"
    fi

    # Direnv per-directory environment
    if command -v direnv &>/dev/null; then
        local direnv_cache="$SHELL_CACHE_DIR/direnv-hook.zsh"
        _refresh_cache "$direnv_cache" 'direnv hook zsh' "$commands[direnv]" \
            && source "$direnv_cache"
    fi

    # Vivid ls colors. The theme name is baked into vivid's binary, so
    # binary mtime is the only invalidator.
    if command -v vivid &>/dev/null; then
        local vivid_cache="$SHELL_CACHE_DIR/vivid-ls-colors"
        _refresh_cache "$vivid_cache" 'vivid generate tokyonight-night' \
            "$commands[vivid]" \
            && export LS_COLORS="$(<$vivid_cache)"
    fi
}

# zoxide smart directory navigation. ztop helper lives as an autoloaded
# function in $SHELL_FUNCTIONS_DIR.
setup_zoxide() {
    command -v zoxide &>/dev/null || return
    local zoxide_cache="$SHELL_CACHE_DIR/zoxide-init.zsh"
    _refresh_cache "$zoxide_cache" 'zoxide init zsh' "$commands[zoxide]" \
        && source "$zoxide_cache"
    export _ZO_ECHO=1                                                  # Print matched dir before cd
    export _ZO_RESOLVE_SYMLINKS=1                                      # Resolve symlinks to true path
    export _ZO_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zoxide"
    alias cdi="zi"                                                     # Interactive directory selection
}

setup_integrations
setup_zoxide

# Register atuin-fzf-history as a ZLE widget. The function body is autoloaded
# from $SHELL_FUNCTIONS_DIR on first ^R press. Binding the widget requires
# `zle -N` to know the name — the function need not exist yet.
# This block must run AFTER setup_integrations: the cached fzf init bound
# viins/vicmd ^R to fzf-history-widget, and these overrides win by coming
# last (atuin search on ^R; vi redo restored in vicmd).
zle -N atuin-fzf-history
if command -v fzf &>/dev/null; then
    bindkey -M viins '^R' atuin-fzf-history
    bindkey -M vicmd '^R' redo
fi
