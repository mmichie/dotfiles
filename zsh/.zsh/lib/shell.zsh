#!/bin/zsh

# Shell options setup
setup_shell_options() {
    setopt interactive_comments
    setopt long_list_jobs
    setopt prompt_subst
    setopt rm_star_silent
}

# Setup History
setup_history() {
    # History file configuration
    export HISTFILE="$HOME/.zsh_history"
    export HISTSIZE=1000000
    export SAVEHIST=1000000

    # History options
    setopt SHARE_HISTORY          # Share history between all sessions
    setopt INC_APPEND_HISTORY_TIME
    setopt HIST_EXPIRE_DUPS_FIRST # Expire duplicate entries first when trimming history
    setopt HIST_IGNORE_ALL_DUPS   # Ignore duplicated entries
    setopt HIST_REDUCE_BLANKS     # Remove superfluous blanks
    setopt HIST_IGNORE_SPACE      # Don't record an entry starting with a space
    setopt HIST_FIND_NO_DUPS      # Do not display duplicates in history search
    setopt HIST_VERIFY            # Show command with history expansion before running it
}

# Setup aliases
setup_aliases() {
    # Common aliases
    alias history="history 1" # behave more like bash
    alias gclean="git_cleanup"
    alias dclean="docker_cleanup"
    alias grep="grep --color=auto -d skip"
    alias grpe="grep --color=auto -d skip"
    alias screen="tmux"
    alias ssh="ssh -A -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -o ConnectTimeout=10 -o VisualHostKey=yes -o IdentitiesOnly=yes"
    alias nsr="netstat -rn"
    alias nsa="netstat -an | sed -n '1,/Active UNIX domain sockets/p'"
    alias lsock="sudo /usr/sbin/lsof -i -P"
    alias keypress="read -s -n1 keypress; echo \$keypress"
    alias loadenv='export $(grep -v "^#" .env | xargs)'

    # Directory navigation
    alias :="cd .."
    alias ::="cd ../.."
    alias :::="cd ../../.."
    alias ::::="cd ../../../.."
    alias :::::="cd ../../../../.."
    alias ::::::="cd ../../../../../.."
}

# Dircolors setup
setup_dircolors() {
    if [[ "$TERM" != "dumb" ]]; then
        local dircolors_cmd="$(whence gdircolors 2>/dev/null || whence dircolors 2>/dev/null)"
        local dir_colors="$HOME/.dircolors"

        if [[ -x "$dircolors_cmd" ]] && [[ -r "$dir_colors" ]]; then
            eval "$($dircolors_cmd -b "$dir_colors")"
        elif [[ -x "$dircolors_cmd" ]]; then
            eval "$($dircolors_cmd -b)"
        fi
    fi
}

# Readline setup
setup_readline() {
    # Enable vi command mode
    bindkey -v

    # Basic navigation bindings
    bindkey '^A' beginning-of-line
    bindkey '^E' end-of-line
    bindkey '^D' delete-char
    bindkey '^L' clear-screen

    # History search bindings
    bindkey '^R' history-incremental-search-backward
    bindkey '^[A' up-line-or-search
    bindkey '^[B' down-line-or-search
}

# Setup completions
setup_completions() {
    autoload -Uz compinit
    compinit

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

# GOPATH setup
setup_gopath() {
    if [[ -z "$GOPATH" ]]; then
        export GOPATH="$HOME/workspace/go"
        mkdir -p "$GOPATH"
        path=($path $GOPATH/bin)
        export GOPROXY="https://proxy.golang.org,direct"
    fi
}

# pyenv setup
setup_pyenv() {
    export PYENV_ROOT="$HOME/.pyenv"
    if [[ -d "$PYENV_ROOT/bin" ]] && [[ -x "$PYENV_ROOT/bin/pyenv" ]]; then
        path=($PYENV_ROOT/bin $path)
        eval "$(pyenv init -)"
    fi
}

# Cron job setup for history backup
ensure_cron_job_exists() {
    local cron_job="0 0 * * 0 . $HOME/.zshrc; backup_shell_history"
    if ! crontab -l | grep -Fq "$cron_job"; then
        (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
    fi
}

# Backup shell history
backup_shell_history() {
    local backup_dir="$HOME/.shell_history_backups"
    mkdir -p "$backup_dir"
    local timestamp=$(date +"%Y%m%d%H%M%S")
    tar -czf "$backup_dir/zsh_history_$timestamp.tar.gz" -C "$HOME" .zsh_history
}

# Git utilities
git_cleanup() {
    git fetch --prune
    git branch --merged | grep -v "\*" | xargs -n 1 git branch -d
}

# Docker utilities
docker_cleanup() {
    docker system prune -af
    docker volume prune -f
}
