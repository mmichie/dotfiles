#!/bin/zsh

# Setup completions
# Note: compinit is already called in .zshrc for faster startup
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

    # Directory handling completions
    compdef _directories cd
    compdef _directories pushd
    compdef _directories mkdir
    compdef _directories rmdir

    # File and job handling completions
    compdef _files ln chmod chown chgrp
    compdef _jobs fg bg disown jobs
}
