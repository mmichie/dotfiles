#!/bin/zsh

# Completion system: compinit + completion styling. Must be sourced before
# 50-integrations.zsh — the cached tool inits there call compdef.

# Load completion system. compinit -C is fast but doesn't notice fpath
# changes on its own; fingerprint fpath into a sidecar file and rebuild only
# when it shifts. The sidecar (not a line appended to the dump) keeps the
# dump pristine for zcompile and costs a fork-free $(<...) instead of a grep.
# fpath is finalized in .zshrc before the module loop; if an earlier module
# ever shifted it, the fingerprint mismatch forces a rebuild rather than
# serving a stale dump.
ZSH_COMPDUMP="$SHELL_CACHE_DIR/.zcompdump"
autoload -Uz compinit
# (F) newline-join: a separator-free join could alias two different
# fpaths whose element boundaries merely shifted.
_fpath_fingerprint="${(F)fpath}"
_compinit_rebuild=1
if [[ -f "$ZSH_COMPDUMP" && -r "$ZSH_COMPDUMP.fpath" ]] \
    && [[ "$(<"$ZSH_COMPDUMP.fpath")" == "$_fpath_fingerprint" ]]; then
    compinit -C -d "$ZSH_COMPDUMP"
    # Self-heal: -C trusts the dump blindly, and the fingerprint cannot see
    # corruption — a truncated/garbled dump (crashed shell, disk damage)
    # would otherwise break completion in EVERY future shell. An intact
    # dump always populates _comps; empty means the load failed, so fall
    # through to the full rebuild below.
    if (( ${#_comps} > 0 )); then
        _compinit_rebuild=0
        # One-time backfill after deploys: compile the dump if no wordcode yet.
        [[ -f "$ZSH_COMPDUMP.zwc" ]] || zcompile "$ZSH_COMPDUMP" 2>/dev/null
    fi
fi
if (( _compinit_rebuild )); then
    command rm -f "$ZSH_COMPDUMP" "$ZSH_COMPDUMP.zwc"
    compinit -i -d "$ZSH_COMPDUMP"
    zcompile "$ZSH_COMPDUMP" 2>/dev/null
    print -r -- "$_fpath_fingerprint" >| "$ZSH_COMPDUMP.fpath"
fi
unset _fpath_fingerprint _compinit_rebuild

setup_completions() {
    # Completion caching
    zstyle ':completion:*' use-cache on
    zstyle ':completion:*' cache-path "$SHELL_CACHE_DIR/compcache"

    # Case-insensitive and partial-word completion matching
    zstyle ':completion:*' matcher-list \
        'm:{a-zA-Z}={A-Za-z}' \
        'r:|[._-]=* r:|=*' \
        'l:|=* r:|=*'

    # Menu selection (arrow keys to navigate completions)
    zstyle ':completion:*' menu select
    zmodload zsh/complist

    # Command specific completions
    compdef _command command
    compdef _signal kill
    compdef _user finger pinky

    # Directory handling completions. cd/pushd deliberately NOT overridden:
    # stock _cd also completes directory-stack entries (cd -<TAB>), CDPATH,
    # and named directories, which _directories cannot.
    compdef _directories mkdir
    compdef _directories rmdir

    # File and job handling completions
    compdef _files ln chmod chown chgrp
    compdef _jobs fg bg disown jobs
}

setup_completions
