#!/bin/bash

# Constants
readonly AGENT_SOCKET="$HOME/.ssh/.ssh-agent-socket"
readonly AGENT_INFO="$HOME/.ssh/.ssh-agent-info"

# Detect only the architecture
detect_architecture() {
    local arch=$(uname -m)
    case "$arch" in
        x86_64) echo 'x86_64' ;;
        aarch64|arm64) echo 'arm64' ;;  # Handle both identifiers for ARM64
        *) echo 'unknown' ;;
    esac
}

# Detect shell platform
detect_shell_platform() {
    case "$OSTYPE" in
        linux*) echo 'LINUX' ;;
        darwin*) echo 'OSX' ;;
        freebsd*) echo 'BSD' ;;
        cygwin*) echo 'CYGWIN' ;;
        *) echo 'OTHER' ;;
    esac
}

# SSH agent handling
handle_ssh_agent() {
    if [[ -s "$AGENT_INFO" ]]; then
        source "$AGENT_INFO"
    fi

    ssh-add -l &>/dev/null
    local status=$?

    if [[ -S "$AGENT_SOCKET" ]] && [[ $status -ne 0 ]]; then
        echo "Agent socket stale, removing it!"
        rm "$AGENT_SOCKET"
    fi

    if [[ -z "$SSH_AGENT_PID" ]] || ! ps -p "$SSH_AGENT_PID" &>/dev/null || [[ $status -ne 0 ]]; then
        echo "Re-starting Agent for $USER"
        ssh-agent -a "$AGENT_SOCKET" >"$AGENT_INFO"
        source "$AGENT_INFO"
        ssh-add
    else
        echo "Agent Already Running"
    fi
}

# Update PS1 prompt
update_ps1() {
    local os_type=$(detect_shell_platform)
    local arch_type=$(detect_architecture)
    local platform_cmd="${os_type}-${arch_type}"
    local powerline_cmd

    case "$platform_cmd" in
        OSX-x86_64) powerline_cmd="$HOME/bin/powerline-go-darwin-amd64" ;;
        OSX-arm64) powerline_cmd="$HOME/bin/powerline-go-darwin-arm64" ;;
        LINUX-arm64) powerline_cmd="$HOME/bin/powerline-go-linux-arm64" ;;
        LINUX-x86_64) powerline_cmd="$HOME/bin/powerline-go-linux-amd64" ;;
    esac

    # Check if the powerline_cmd is executable
    if [[ -n "$powerline_cmd" ]] && [[ -x "$powerline_cmd" ]]; then
        PS1="$($powerline_cmd -error $? -jobs $(jobs -p | wc -l))"
    else
        echo "Error: powerline-go command not found or not executable at $powerline_cmd"
        PS1="[\u@\h \W]\$ "  # Setting a default prompt if powerline-go is not found
    fi

    history -a
    history -c
    history -r
}

# Environment setup
setup_environment() {
    export PATH="$PATH:$HOME/bin:/usr/local/bin:$HOME/.local/bin:/usr/local/go/bin"
    export P4CONFIG=".p4config"
    export P4EDITOR="vim -f"
    export EDITOR="vim -f"
    export LC_ALL="en_US.UTF-8"
    export LANG="en_US.UTF-8"
    export TZ="US/Pacific"
    export VAGRANT_DEFAULT_PROVIDER="aws"
}

# GOPATH setup
setup_gopath() {
    if [[ -z "$GOPATH" ]]; then
        export GOPATH="$HOME/workspace/go"
        mkdir -p "$GOPATH"
        export PATH="$PATH:$GOPATH/bin"
        export GOPROXY="https://proxy.golang.org,direct"
    fi
}

# Platform-specific aliases and setup
setup_platform_specific() {
    local os_type=$(detect_shell_platform)

    case "$os_type" in
        OSX)
            export HOMEBREW_NO_ANALYTICS=1
            #alias slock='pmset displaysleepnow && ssh 172.17.122.15 "DISPLAY=:0 slock"'
            alias brew="/opt/homebrew/bin/brew"
            if type brew &>/dev/null && [[ -r "$(brew --prefix)/etc/bash_completion" ]]; then
                source "$(brew --prefix)/etc/bash_completion"
            fi
            export PATH="$HOME/bin:$(brew --prefix)/sbin:$(brew --prefix)/bin:$PATH"
            alias ls="gls --color=auto"
            if [[ -r "$HOME/.iterm2_shell_integration.bash" ]]; then
                source "$HOME/.iterm2_shell_integration.bash"
            fi
            ;;
        LINUX)
            export NO_AT_BRIDGE=1
            alias open="xdg-open"
            alias ls="ls --color=auto"
            if [[ -x "/usr/bin/dircolors" ]]; then
                if [[ -r "$HOME/.dircolors" ]]; then
                    eval "$(dircolors -b "$HOME/.dircolors")"
                else
                    eval "$(dircolors -b)"
                fi
                alias ls="ls --color=auto"
                alias grep="grep --color=auto"
                alias fgrep="fgrep --color=auto"
                alias egrep="egrep --color=auto"
            fi
            export GCC_COLORS="error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01"
            ;;
    esac
}

# Aliases
setup_aliases() {
    alias grep="grep --color=auto -d skip"
    alias grpe="grep --color=auto -d skip"
    alias screen="tmux"
    alias ssh="ssh -o StrictHostKeyChecking=accept-new -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -o ConnectTimeout=10 -o VisualHostKey=yes -o IdentitiesOnly=yes"
    alias nsr="netstat -rn"
    alias nsa="netstat -an | sed -n '1,/Active UNIX domain sockets/p'"
    alias lsock="sudo /usr/sbin/lsof -i -P"
    alias keypress="read -s -n1 keypress; echo \$keypress"
    alias :="cd .."
    alias ::="cd ../.."
    alias :::="cd ../../.."
    alias ::::="cd ../../../.."
    alias :::::="cd ../../../../.."
    alias ::::::="cd ../../../../../.."
}

# Functions
man() {
    env \
        LESS_TERMCAP_md=$'\e[1;36m' \
        LESS_TERMCAP_me=$'\e[0m' \
        LESS_TERMCAP_se=$'\e[0m' \
        LESS_TERMCAP_so=$'\e[1;40;92m' \
        LESS_TERMCAP_ue=$'\e[0m' \
        LESS_TERMCAP_us=$'\e[1;32m' \
        command man "$@"
}

http_headers() {
    /usr/bin/curl -I -L "$@"
}

sshtunnel() {
    if [[ $# -ne 3 ]]; then
        echo "usage: sshtunnel host remote-port local-port"
    else
        /usr/bin/ssh "$1" -L "$3":localhost:"$2"
    fi
}

catfiles() {
    local file
    for file in "$@"; do
        echo "filename: $file"
        cat "$file"
    done
}

# Shell options
setup_shell_options() {
    shopt -s cmdhist
    shopt -s histappend
    shopt -s checkwinsize
    shopt -s execfail
}

# History
setup_history() {
    export HISTCONTROL="ignoreboth"
    export HISTSIZE=100000
    export HISTIGNORE="&:ls:[bf]g:exit"
}

# Dircolors setup
setup_dircolors() {
    if [[ "$TERM" != "dumb" ]]; then
        local dircolors_cmd="$(which gdircolors 2>/dev/null || which dircolors 2>/dev/null)"
        local dir_colors="$HOME/.dircolors"
        if [[ -x "$dircolors_cmd" ]] && [[ -r "$dir_colors" ]]; then
            eval "$($dircolors_cmd -b "$dir_colors")"
        elif [[ -x "$dircolors_cmd" ]]; then
            eval "$($dircolors_cmd -b)"
        else
            echo "No dircolors command found, using default LS_COLORS"
        fi
        alias grep="grep --color=auto"
        alias fgrep="fgrep --color=auto"
        alias egrep="egrep --color=auto"
    fi
}

# Readline setup
setup_readline() {
    set -o vi
    bind -m vi-command 'Control-a: vi-insert-beg'
    bind -m vi-command 'Control-e: vi-append-eol'
    bind -m vi-command '"ZZ": emacs-editing-mode'
    bind -m vi-insert '"\M-[A": ""'
    bind -m vi-insert '"\M-[5~": ""'
    bind -m vi-insert 'Control-p: previous-history'
    bind -m vi-insert '"\M-[B": ""'
    bind -m vi-insert '"\M-[6~": ""'
    bind -m vi-insert 'Control-n: next-history'
    bind -m vi-insert 'Control-a: beginning-of-line'
    bind -m vi-insert 'Control-e: end-of-line'
    bind -m vi-insert 'Control-d: delete-char'
    bind -m vi-insert 'Control-l: clear-screen'
    bind -m emacs '"\ev": vi-editing-mode'
}

# Completions
setup_completions() {
    complete -A setopt set
    complete -A user groups id
    complete -A binding bind
    complete -A helptopic help
    complete -A alias {,un}alias
    complete -A signal -P '-' kill
    complete -A stopped -P '%' fg bg
    complete -A job -P '%' jobs disown
    complete -A variable readonly unset
    complete -A file -A directory ln chmod
    complete -A user -A hostname finger pinky
    complete -A directory find cd pushd {mk,rm}dir
    complete -A file -A directory -A user chown
    complete -A file -A directory -A group chgrp
    complete -o default -W 'Makefile' -P '-o ' qmake
    complete -A command man which whatis whereis sudo info apropos
    complete -A file {,z}cat pico nano vi {,{,r}g,e,r}vi{m,ew} vimdiff elvis emacs {,r}ed e{,x} joe jstar jmacs rjoe jpico {,z}less {,z}more p{,g}
}

# pyenv setup
setup_pyenv() {
    export PYENV_ROOT="$HOME/.pyenv"
    if [[ -d "$PYENV_ROOT/bin" ]] && [[ -x "$PYENV_ROOT/bin/pyenv" ]]; then
        export PATH="$PYENV_ROOT/bin:$PATH"
        eval "$(pyenv init -)"
    fi
}

# Check and add cron job for backing up shell history
ensure_cron_job_exists() {
    local cron_job="0 0 * * 0 . $HOME/.bashrc; backup_shell_history"
    if ! crontab -l | grep -Fq "$cron_job"; then
        (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
        echo "Cron job added for backing up shell history."
    else
        echo "Cron job already exists."
    fi
}

# Backup shell history
backup_shell_history() {
    local backup_dir="$HOME/.shell_history_backups"
    mkdir -p "$backup_dir"
    local timestamp=$(date +"%Y%m%d%H%M%S")
    tar -czf "$backup_dir/bash_history_$timestamp.tar.gz" -C "$HOME" .bash_history
}
