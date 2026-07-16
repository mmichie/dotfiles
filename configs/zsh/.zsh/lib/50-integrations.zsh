#!/bin/zsh

# Third-party shell integrations: atuin, direnv, vivid, zoxide, work profile.
#
# Slow `tool init` / `tool generate` commands are cached to disk and
# re-run only when the tool's binary (or its config) is newer than the
# cache. `eval $(tool init zsh)` ran ~50-100ms per shell; sourcing a
# cached file is closer to 1ms.

# Re-run `cmd` and write its output to $cache_path when the command
# string or any of $invalidators... changed since the cache was written.
# Otherwise leave it alone. Returns nonzero when the cache could not be
# (re)generated — callers should `&& source` so a failed tool init
# degrades to "tool not set up this shell" instead of sourcing garbage.
#
# Staleness is detected three ways, because mtime alone cannot see nix
# rebuilds: everything under /nix/store has its mtime clamped to the
# epoch, so a rebuilt binary is NEVER newer than its cache and the init
# scripts silently freeze at whatever version first populated them
# (this kept a fixed chevron from taking effect). What does change per
# rebuild is the resolved store path, so:
#   1. the generating command (must stay single-line) is recorded as the
#      first line of a $cache_path.dep sidecar — an edited init line
#      (vivid theme, atuin flags) is invisible to the other two checks
#      and would otherwise serve stale output until the binary's store
#      path happened to change;
#   2. the symlink-resolved paths of all invalidators fill the rest of
#      the sidecar and any difference forces a refresh;
#   3. the -nt mtime check stays, for mutable invalidators (config
#      files, non-nix installs).
# Sourceable caches (*.zsh only — data files like vivid-ls-colors are not
# scripts) are zcompiled so later shells load wordcode; a missing .zwc next
# to an existing cache is backfilled once (post-deploy).
_refresh_cache() {
    local cache_path="$1"
    shift
    local cmd="$1"
    shift
    local inv
    # ${inv:A}: absolute path with symlinks resolved, pure zsh (no
    # fork). Only EXISTING invalidators are stamped — a missing one
    # carries no evidence either way and must leave the cache alone
    # (same contract as the -e guard on the mtime check below).
    local -a resolved
    for inv in "$@"; do
        [[ -e $inv ]] && resolved+=("${inv:A}")
    done
    local stamp_path="$cache_path.dep"
    local -a recorded
    [[ -f $stamp_path ]] && recorded=(${(f)"$(<"$stamp_path")"})
    # Line 1 of the sidecar is the command, the rest are resolved paths.
    # The command always participates in the comparison; the paths only
    # when at least one invalidator resolved (empty = no evidence).
    if [[ ! -f $cache_path || "$cmd" != "${recorded[1]:-}" \
        || ( ${#resolved} -gt 0 && "${(F)resolved}" != "${(F)recorded[2,-1]}" ) ]]; then
        _write_cache "$cache_path" "$cmd" || return 1
        _stamp_cache "$stamp_path" "$cmd" "$@"
        return 0
    fi
    for inv in "$@"; do
        [[ -e $inv && $inv -nt $cache_path ]] || continue
        _write_cache "$cache_path" "$cmd" || return 1
        _stamp_cache "$stamp_path" "$cmd" "$@"
        return 0
    done
    [[ "$cache_path" == *.zsh && ! -f "$cache_path.zwc" ]] && _zcompile_cache "$cache_path"
    return 0
}

# Stamp by re-resolving AFTER generation, not before: `tool init` may
# create its own config on first run (atuin does), and a pre-generation
# stamp would make the next shell see a "new" invalidator and rebuild
# the cache once more per appearance.
_stamp_cache() {
    local stamp_path="$1" cmd="$2"
    shift 2
    local inv
    local -a resolved
    for inv in "$@"; do
        [[ -e $inv ]] && resolved+=("${inv:A}")
    done
    local -a stamp_lines=("$cmd" "${resolved[@]}")
    print -r -- "${(F)stamp_lines}" > "$stamp_path"
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

# Fork-free stand-in for `atuin uuid`, which atuin's init runs once per
# shell to mint ATUIN_SESSION — a fork+exec of the whole Rust binary,
# ~15ms and the largest single startup cost left after the tool inits
# were cached. Emits the same dashless lowercase UUIDv7: 48-bit unix-ms
# timestamp, version nibble, 74 random bits. Entropy comes from
# /dev/urandom via sysread (zsh/system builtin — no subprocess); the
# result lands in $REPLY because a $(...) capture would fork the very
# subshell this exists to avoid. Falls back to the real `atuin uuid`
# when the module or RNG read is unavailable: slower, never wrong.
_atuin_session_uuid() {
    emulate -L zsh
    local raw='' hex='' c ts
    local LC_ALL=C # byte-wise ${#raw} and ${(s::)...}: raw is binary
    if ! zmodload zsh/system zsh/datetime 2>/dev/null \
        || ! sysread -s 10 raw < /dev/urandom 2>/dev/null \
        || (( ${#raw} != 10 )); then
        REPLY="$(atuin uuid 2>/dev/null)"
        [[ -n "$REPLY" ]]
        return
    fi
    for c in "${(@s::)raw}"; do
        hex+="${(l:2::0:)$(( [##16] #c ))}"
    done
    ts="${(l:12::0:)$(( [##16] ${EPOCHREALTIME%.*} * 1000 + 10#${${EPOCHREALTIME#*.}[1,3]} ))}"
    # ts(12) + version nibble 7 + 12 random bits + variant nibble
    # (10xx -> 8-b, two of rand_b's 62 bits) + 60 more random bits.
    REPLY="${ts}7${hex[1,3]}$(( [##16] 0x${hex[4]} & 0x3 | 0x8 ))${hex[5,19]}"
    REPLY="${REPLY:l}"
}

# Rewrite the one session-mint line of `atuin init zsh` output to call
# the generator above. Anchored on the literal upstream text and
# fail-open: if a future atuin changes that line, nothing matches, the
# emitted fork survives, and startup gets slower — never incorrect.
_atuin_filter_init() {
    local l
    while IFS= read -r l; do
        if [[ "$l" == *'export ATUIN_SESSION=$(atuin uuid)'* ]]; then
            print -r -- "${l%%export ATUIN_SESSION=*}_atuin_session_uuid && export ATUIN_SESSION=\"\$REPLY\""
        else
            print -r -- "$l"
        fi
    done
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
    # The init is piped through _atuin_filter_init to swap the per-shell
    # `$(atuin uuid)` session fork for the fork-free generator above.
    # pipefail (subshell-scoped, generation-time only) keeps a failed
    # `atuin init` from being cached as a truncated script the pipeline's
    # successful filter would otherwise mask.
    if command -v atuin &>/dev/null; then
        local atuin_cache="$SHELL_CACHE_DIR/atuin-init.zsh"
        _refresh_cache "$atuin_cache" \
            '( setopt pipefail; atuin init zsh --disable-up-arrow --disable-ctrl-r | _atuin_filter_init )' \
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

    # Vivid ls colors. Themes are compiled into vivid's binary — no theme
    # file to watch; the theme *name* is caught by the command fingerprint.
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
