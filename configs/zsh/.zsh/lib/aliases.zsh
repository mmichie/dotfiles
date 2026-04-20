#!/bin/zsh

# Git utilities
git_cleanup() {
    git fetch --prune || return
    local default_branch=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
    default_branch=${default_branch:-main}
    local current_branch=$(git branch --show-current)
    local branches=$(git branch --merged --format='%(refname:short)' |
        grep -vE "^(${default_branch}|master|main|${current_branch})$")
    [[ -z "$branches" ]] && { echo "No merged branches to delete."; return; }
    echo "$branches" | xargs -n 1 git branch -d
}

# Docker utilities
docker_cleanup() {
    docker system prune -af
    docker volume prune -f
}

setup_aliases() {
    # Check if bat is installed and set up alias for cat
    if command -v bat &>/dev/null; then
        alias cat="bat --style=plain --paging=never --wrap=never"
    fi

    # Common aliases
    alias history="history 1" # behave more like bash
    alias gclean="git_cleanup"
    alias dclean="docker_cleanup"
    alias grep="grep --color=auto -d skip"
    alias grpe="grep --color=auto -d skip"

    # Configure pagers - use moor if available, otherwise less
    if command -v moor &>/dev/null; then
        # moor has better mouse support and modern features
        alias less="moor"
        alias more="moor"
        alias mr="moor"
        alias mw="moor -wrap"
    else
        # Fallback to less with horizontal scrolling and mouse support
        alias less="less -S --mouse"
        alias more="less"
    fi

    # New modern tool aliases
    if command -v duf &>/dev/null; then
        alias df="duf"
    fi

    if command -v jless &>/dev/null; then
        alias jl="jless"
    fi

    if command -v gping &>/dev/null; then
        alias pg="gping"
    fi

    if command -v bandwhich &>/dev/null; then
        alias bw="sudo bandwhich"
    fi
    alias screen="tmux"
    # Nested tmux on a separate socket — gets orange theme via TMUX_LEVEL
    tnest() { TMUX= tmux -L nested new-session -A -s nested "$@"; }
    # ssh hardening lives in ~/.ssh/config (Host *); an alias here would be
    # shadowed by the ssh() wrapper function in ssh.zsh (which uses `command ssh`).
    alias nsr="netstat -rn"
    alias nsa="netstat -an | sed -n '1,/Active UNIX domain sockets/p'"
    alias lsock="sudo lsof -i -P"
    alias keypress="read -s -n1 keypress; echo \$keypress"

    # Directory navigation
    alias :="cd .."
    alias ::="cd ../.."
    alias :::="cd ../../.."
    alias ::::="cd ../../../.."
    alias :::::="cd ../../../../.."
    alias ::::::="cd ../../../../../.."
    alias du='du -h'
    alias mkdir='mkdir -p'
    alias ..='cd ..'
    alias ...='cd ../..'
    alias ....='cd ../../..'
    alias .....='cd ../../../..'
    alias -- -='cd -'
    alias path='echo -e ${PATH//:/\\n}'

    # Suffix aliases
    alias -s {txt,md,markdown,rst}=$EDITOR
    alias -s {gif,jpg,jpeg,png}='open'
    alias -s {html,htm}='open'
}
