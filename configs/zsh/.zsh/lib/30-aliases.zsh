#!/bin/zsh

# Aliases. User-callable helper functions (git_cleanup, docker_cleanup, tnest)
# live as autoloaded functions in $SHELL_FUNCTIONS_DIR.

setup_aliases() {
    if command -v bat &>/dev/null; then
        alias cat="bat --style=plain --paging=never --wrap=never"
    fi

    # history is a function now (functions/history: bash-style `history N`).
    # Drop the alias it replaced, so `source ~/.zshrc` upgrades a shell that
    # predates the change: left in place, it rewrites `history 5` to
    # `history 1 5` before the function sees it.
    unalias history 2>/dev/null
    alias gclean="git_cleanup"
    alias dclean="docker_cleanup"
    # chevron subsumes the old shell system_health: ~33ms warm-cache vs 5-13s.
    command -v chevron &>/dev/null && alias health="chevron health"
    # PTY-based per-command output capture (chevron-1yn.4). Output bytes
    # land at $XDG_RUNTIME_DIR/chevron/outputs/<ulid>.log; query via
    # `chevron history --grep-output PATTERN` or `chevron history --show-output <id>`.
    # Use deliberately on commands worth remembering: `chcap cargo build`,
    # `chcap make release`, etc. Skip for interactive programs (vim, ssh).
    command -v chevron &>/dev/null && alias chcap="chevron capture"
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
    alias keypress="read -sk1 keypress; echo \$keypress"  # zsh read: -k1 reads one char (-n is a bashism)

    # Directory navigation. No bare `:` alias: aliasing the POSIX no-op
    # expands at parse time into every later-sourced file that uses `:` at
    # command position (it once turned the banner stamp into `cd ..`).
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

    # Suffix aliases: `foo.md` opens in $EDITOR; images and HTML go to the
    # platform opener. `open` is macOS-only (Debian-family Linux ships the
    # name as openvt, NixOS has none), so Linux uses xdg-open and defines
    # nothing when no opener is installed rather than binding `foo.png` to
    # a command that cannot exist.
    alias -s {txt,md,markdown,rst}=$EDITOR
    local opener=''
    if is_osx; then
        opener=open
    elif (( $+commands[xdg-open] )); then
        opener=xdg-open
    fi
    if [[ -n "$opener" ]]; then
        alias -s {gif,jpg,jpeg,png}="$opener"
        alias -s {html,htm}="$opener"
    fi
}

# Numeric directory-stack jumps: type `1`, `2`, ..., `5` to go to the entry
# `d` (dirs -v) lists under that number. +N, not -N: without PUSHD_MINUS, -N
# counts from the bottom of the stack and lands on a different entry.
for _n in 1 2 3 4 5; do
    eval "$_n() { cd +$_n; }"
done
unset _n

setup_aliases
