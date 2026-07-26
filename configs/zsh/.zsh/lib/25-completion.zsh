#!/bin/zsh

# Completion system: compinit + completion styling. Must be sourced before
# 50-integrations.zsh — the cached tool inits there call compdef.

# Load completion system. compinit -C is fast but rescans nothing — neither
# the fpath list nor the directories on it; fingerprint both into a sidecar
# file and rebuild only when they shift. The sidecar (not a line appended
# to the dump) keeps the dump pristine for zcompile and costs a fork-free
# $(<...) instead of a grep.
# fpath is finalized in .zshrc before the module loop; if an earlier module
# ever shifted it, the fingerprint mismatch forces a rebuild rather than
# serving a stale dump.
ZSH_COMPDUMP="$SHELL_CACHE_DIR/.zcompdump"
autoload -Uz compinit
# The fingerprint is the fpath LIST plus each entry's directory mtime. The
# list alone is not enough: -C never rescans directory contents, so a
# completion file dropped into an already-listed dir (nix's
# generation-stable site-functions, $SHELL_FUNCTIONS_DIR) went unnoticed
# until fpath itself moved. A directory's mtime changes on file
# add/remove/rename — exactly the events that need a rebuild; editing an
# existing _file's body does not. Cost is one stat per entry (~16), no
# readdir: a glob per dir would eat what the -C path saves.
# /nix/store mtimes are clamped to the epoch and startup writes nothing
# into the config tree, so the signal does not churn between boots.
zmodload -F zsh/stat b:zstat 2>/dev/null
# (F) newline-join: a separator-free join could alias two different
# fpaths whose element boundaries merely shifted. Computed once and reused
# for the write below — the compare and the sidecar must never disagree.
# Unreadable or missing dirs stamp a fixed placeholder: stable across
# boots, and no mtime can collide with it.
_fpath_stamps=()
for _fpath_dir in $fpath; do
    zstat -A _fpath_mtime +mtime -- "$_fpath_dir" 2>/dev/null || _fpath_mtime=(none)
    _fpath_stamps+=("$_fpath_dir:$_fpath_mtime[1]")
done
_fpath_fingerprint="${(F)_fpath_stamps}"
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
unset _fpath_fingerprint _compinit_rebuild _fpath_stamps _fpath_dir _fpath_mtime

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
