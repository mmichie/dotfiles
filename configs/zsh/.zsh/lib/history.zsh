#!/bin/zsh

# Setup History with advanced features
setup_history() {
    # History file configuration
    export HISTFILE="$HOME/.zsh_history"
    export HISTSIZE=600000        # 20% larger than SAVEHIST for HIST_EXPIRE_DUPS_FIRST cushion
    export SAVEHIST=500000        # History entries saved to disk

    # Enhanced history options
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

    # Interactive history helpers

    hgrep() {
        if [[ $# -eq 0 ]]; then
            echo "Usage: hgrep <pattern>"
            return 1
        fi
        fc -l 1 -1 | grep --color=auto -i "$@"
    }

    recent() {
        local n=${1:-10}
        history -${n}
    }

    remember() {
        if [[ $# -eq 0 ]]; then
            echo "Usage: remember <command> - Save important command for future reference"
            return 1
        fi
        local remember_file="$HOME/.important_commands"
        echo "$(date +"%Y-%m-%d %H:%M:%S") $@" >> "$remember_file"
        echo "Command saved to $remember_file"
    }

    recalls() {
        local remember_file="$HOME/.important_commands"
        if [[ ! -f "$remember_file" ]]; then
            echo "No saved commands yet."
            return 0
        fi
        if [[ $# -eq 0 ]]; then
            cat "$remember_file"
        else
            grep -i "$@" "$remember_file"
        fi
    }
}
