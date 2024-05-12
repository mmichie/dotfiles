#!/bin/bash

# Prevent multiple sourcing
[[ "$BASHRC_LOADED" == "true" ]] && return
BASHRC_LOADED=true

# Exit if not running interactively
[[ $- != *i* ]] && return

# Source global definitions if available
[[ -f /etc/bashrc ]] && source /etc/bashrc

# User specific environment and startup programs
export HOMEBREW_NO_ANALYTICS=1

# Detect shell platform
detect_shell_platform() {
    case "$OSTYPE" in
        *'linux'*) echo 'LINUX' ;;
        *'darwin'*) echo 'OSX' ;;
        *'freebsd'*) echo 'BSD' ;;
        *'cygwin'*) echo 'CYGWIN' ;;
        *) echo 'OTHER' ;;
    esac
}

SHELL_PLATFORM=$(detect_shell_platform)

# SSH agent handling
handle_ssh_agent() {
    local AGENT_SOCKET=$HOME/.ssh/.ssh-agent-socket
    local AGENT_INFO=$HOME/.ssh/.ssh-agent-info

    if [[ -s "$AGENT_INFO" ]]; then
        source $AGENT_INFO
    fi

    ssh-add -l
    local status=$?

    if [[ -e $AGENT_SOCKET ]] && [ $status -ne 0 ]; then
        echo "Agent socket stale, removing it!"
        rm $AGENT_SOCKET
    fi

    if [[ -z "$SSH_AGENT_PID" || "$SSH_AGENT_PID" != $(pgrep -u $USER ssh-agent) || $status -ne 0 ]]; then
        echo "Re-starting Agent for $USER"
        pkill -15 -u $USER ssh-agent
        eval $(ssh-agent -s -a $AGENT_SOCKET)
        echo "export SSH_AGENT_PID=$SSH_AGENT_PID" >$AGENT_INFO
        echo "export SSH_AUTH_SOCK=$SSH_AUTH_SOCK" >>$AGENT_INFO
        ssh-add
    else
        echo "Agent Already Running"
    fi
}

HOSTNAME=$(hostname)
declare -a SSH_HOSTNAMES=("mattmichie-mbp" "matt-pc" "miley" "matt-pc-wsl")

if [[ " ${SSH_HOSTNAMES[@]} " =~ " $HOSTNAME " ]]; then
    handle_ssh_agent
fi

# Update PS1 prompt
update_ps1() {
    if [ "$SHELL_PLATFORM" == "OSX" ] && [[ -e ~/bin/powerline-go-darwin ]]; then
        PS1="$(~/bin/powerline-go-darwin -error $? -jobs $(jobs -p | wc -l))"
    elif [[ -e ~/bin/powerline-go-linux-amd64 ]]; then
        PS1="$(~/bin/powerline-go-linux-amd64 -error $? -jobs $(jobs -p | wc -l))"
    elif [[ -e ~/bin/powerline-shell.py ]]; then
        PS1="$(~/bin/powerline-shell.py $? 2>/dev/null)"
    else
        PS1="$ "
    fi
    history -a
    history -c
    history -r
}

unset USERNAME
case $TERM in
    xterm* | screen*)
        PROMPT_COMMAND="update_ps1; $PROMPT_COMMAND"
        ;;
esac

# Environment setup
setup_environment() {
    export PATH=$PATH:~/bin:/usr/local/bin:~/.local/bin:/usr/local/go/bin
    export P4CONFIG=.p4config
    export P4EDITOR="vim -f"
    export EDITOR="vim -f"
    export LC_ALL=en_US.UTF-8
    export LANG=en_US.UTF-8
    export TZ='US/Pacific'
    export VAGRANT_DEFAULT_PROVIDER=aws
}

setup_environment

# GOPATH setup
setup_gopath() {
    if [ -z "$GOPATH" ]; then
        export GOPATH="$HOME/workspace/go"
        mkdir -p "$GOPATH"
        export PATH=$PATH:$GOPATH/bin
        export GOPROXY=https://proxy.golang.org,direct
    fi
}

setup_gopath

# Platform-specific aliases and setup
setup_platform_specific() {
    if [ "$SHELL_PLATFORM" == "OSX" ]; then
        alias slock='pmset displaysleepnow && ssh 172.17.122.15 '\''DISPLAY=:0 slock'\'''
        alias brew="/opt/homebrew/bin/brew"
        type "brew" &>/dev/null && [ -s "$(brew --prefix)/etc/bash_completion" ] && . $(brew --prefix)/etc/bash_completion
        export PATH=$HOME/bin:$(brew --prefix)/sbin:$(brew --prefix)/bin:$PATH
        alias ls="gls --color=auto"
        test -e "${HOME}/.iterm2_shell_integration.bash" && source "${HOME}/.iterm2_shell_integration.bash"
    elif [ "$SHELL_PLATFORM" == "LINUX" ]; then
        export NO_AT_BRIDGE=1
        alias open="xdg-open"
        alias ls="ls --color=auto"
        if [ -x /usr/bin/dircolors ]; then
            test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
            alias ls='ls --color=auto'
            alias grep='grep --color=auto'
            alias fgrep='fgrep --color=auto'
            alias egrep='egrep --color=auto'
        fi
        export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'
    fi
}

setup_platform_specific

# Aliases
setup_aliases() {
    alias grep='grep --color=auto -d skip'
    alias grpe='grep --color=auto -d skip'
    alias screen="tmux"
    alias ssh="ssh -A -o StrictHostKeyChecking=accept-new"
    alias nsr='netstat -rn'
    alias nsa='netstat -an | sed -n "1,/Active UNIX domain sockets/ p"'
    alias lsock='sudo /usr/sbin/lsof -i -P'
    alias keypress='read -s -n1 keypress; echo $keypress'
    alias :='cd ..'
    alias ::='cd ../..'
    alias :::='cd ../../..'
    alias ::::='cd ../../../..'
    alias :::::='cd ../../../../..'
    alias ::::::='cd ../../../../../..'
}

setup_aliases

# Functions
man() {
    env \
        LESS_TERMCAP_md=$'\e[1;36m' \
        LESS_TERMCAP_me=$'\e[0m' \
        LESS_TERMCAP_se=$'\e[0m' \
        LESS_TERMCAP_so=$'\e[1;40;92m' \
        LESS_TERMCAP_ue=$'\e[0m' \
        LESS_TERMCAP_us=$'\e[1;32m' \
        man "$@"
}

http_headers() {
    /usr/bin/curl -I -L "$@"
}

sshtunnel() {
    if [ $# -ne 3 ]; then
        echo "usage: sshtunnel host remote-port local-port"
    else
        /usr/bin/ssh "$1" -L "$3":localhost:"$2"
    fi
}

# Shell options
setup_shell_options() {
    shopt -s cmdhist
    shopt -s histappend
    shopt -s checkwinsize
    shopt -s execfail
}

setup_shell_options

# History
setup_history() {
    export HISTCONTROL=ignoreboth
    export HISTSIZE=100000
    export HISTIGNORE="&:ls:[bf]g:exit"
}

setup_history

# Dircolors setup
setup_dircolors() {
    if [ "$TERM" != "dumb" ]; then
        [ -e "$HOME/.dircolors" ] && DIR_COLORS="$HOME/.dircolors"
        [ -e "$DIR_COLORS" ] || DIR_COLORS=""
        if hash dircolors 2>/dev/null; then
            eval "$(dircolors -b "$DIR_COLORS")"
        fi
    fi
}

setup_dircolors

SSH_ENV="$HOME/.ssh/environment"

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

setup_readline

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

setup_completions

test -e "${HOME}/.bash_work_profile" && source "${HOME}/.bash_work_profile"

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"

# pyenv setup
setup_pyenv() {
    export PYENV_ROOT="$HOME/.pyenv"
    if [[ -d $PYENV_ROOT/bin ]] && [[ -x $PYENV_ROOT/bin/pyenv ]]; then
        export PATH="$PYENV_ROOT/bin:$PATH"
        eval "$(pyenv init -)"
    fi
}

setup_pyenv
