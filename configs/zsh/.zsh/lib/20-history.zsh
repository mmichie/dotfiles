#!/bin/zsh

# History configuration. The interactive helpers (hgrep, recent, remember,
# recalls) live as autoloaded functions in $SHELL_FUNCTIONS_DIR.

setup_history() {
    # typeset -g +x, not export: HISTFILE in the environment makes an
    # interactive bash child read — and on exit write bash-format entries
    # into — .zsh_history. +x also strips the export flag when it was
    # inherited from a pre-fix parent (tmux server, old login shells).
    typeset -g +x HISTFILE="$HOME/.zsh_history"
    typeset -g +x HISTSIZE=600000 # 20% larger than SAVEHIST for HIST_EXPIRE_DUPS_FIRST cushion
    typeset -g +x SAVEHIST=500000 # History entries saved to disk

    setopt SHARE_HISTORY          # Share history between all sessions
    setopt EXTENDED_HISTORY       # Save timestamp and duration of command
    setopt HIST_EXPIRE_DUPS_FIRST # Expire duplicate entries first when trimming history
    setopt HIST_IGNORE_ALL_DUPS   # Remove older duplicate from anywhere in history
    setopt HIST_REDUCE_BLANKS     # Remove superfluous blanks (aids deduplication)
    setopt HIST_IGNORE_SPACE      # Don't record an entry starting with a space
    setopt HIST_FIND_NO_DUPS      # Do not display duplicates in history search
    setopt HIST_SAVE_NO_DUPS      # Don't write duplicate entries to history file
    setopt HIST_VERIFY            # Show command with history expansion before running it
    setopt HIST_FCNTL_LOCK        # Use fcntl locking (recommended for concurrent shells)
    setopt HIST_NO_STORE          # Don't store history/fc commands in history

    # HIST_NO_STORE only recognises the history BUILTIN: zsh stops filtering
    # `history ...` lines as soon as a function of that name exists, and
    # functions/history is one. Containment-guarded so re-sourcing .zshrc
    # cannot register the hook twice.
    typeset -ga zshaddhistory_functions
    (( ${zshaddhistory_functions[(Ie)_hist_no_store_history]} )) \
        || zshaddhistory_functions+=(_hist_no_store_history)
}

# zshaddhistory hook: status 1 keeps the line out of the history, with the
# builtin's own grace period (it stays recallable until the next command).
# $1 is the whole line, trailing newline included, which is what lets a bare
# `history` match the whitespace class.
_hist_no_store_history() {
    [[ "$1" != history[[:space:]]* ]]
}

setup_history
