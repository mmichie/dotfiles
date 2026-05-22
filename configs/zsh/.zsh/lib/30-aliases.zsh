#!/bin/zsh

# Aliases. User-callable helper functions (git_cleanup, docker_cleanup, tnest)
# live as autoloaded functions in $SHELL_FUNCTIONS_DIR.

setup_aliases() {
    if command -v bat &>/dev/null; then
        alias cat="bat --style=plain --paging=never --wrap=never"
    fi

    alias history="history 1" # behave more like bash
    alias gclean="git_cleanup"
    alias dclean="docker_cleanup"
    # chevron subsumes the old shell system_health: ~33ms warm-cache vs 5-13s.
    command -v chevron &>/dev/null && alias health="chevron health"
    alias grep="grep --color=auto -d skip"
    alias grpe="grep --color=auto -d skip"

    alias less="less -S --mouse"
    alias more="less"

    # Modern-tool overrides (opt-in via PATH).
    command -v duf       &>/dev/null && alias df="duf"
    command -v gping     &>/dev/null && alias pg="gping"
    command -v bandwhich &>/dev/null && alias bw="sudo bandwhich"

    alias screen="tmux"
    # Note: ssh hardening lives in ~/.ssh/config; the ssh() wrapper in
    # 80-ssh.zsh would shadow an alias here anyway.
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

# Numeric directory-stack jumps: type `1`, `2`, ..., `5` to cd -1, cd -2, etc.
for _n in 1 2 3 4 5; do
    eval "$_n() { cd -$_n; }"
done
unset _n

setup_aliases
