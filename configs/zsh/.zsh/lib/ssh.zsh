#!/bin/zsh

readonly AGENT_SOCKET="$HOME/.ssh/.ssh-agent-socket"
readonly AGENT_INFO="$HOME/.ssh/.ssh-agent-info"
readonly ONEPASSWORD_SOCKET_MACOS="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
readonly ONEPASSWORD_SOCKET_LINUX="$HOME/.1password/agent.sock"

# Pick an SSH agent in preference order:
#   1. 1Password (macOS or Linux)
#   2. Forwarded / externally-set SSH_AUTH_SOCK (ssh -A, systemd user socket)
#   3. Traditional ssh-agent (Linux boxes without 1Password)
handle_ssh_agent() {
    if [[ -S "$ONEPASSWORD_SOCKET_MACOS" ]]; then
        export SSH_AUTH_SOCK="$ONEPASSWORD_SOCKET_MACOS"
        return 0
    elif [[ -S "$ONEPASSWORD_SOCKET_LINUX" ]]; then
        export SSH_AUTH_SOCK="$ONEPASSWORD_SOCKET_LINUX"
        return 0
    fi

    if [[ -n "$SSH_AUTH_SOCK" ]] && [[ -S "$SSH_AUTH_SOCK" ]]; then
        return 0
    fi

    if [[ -s "$AGENT_INFO" ]]; then
        source "$AGENT_INFO"
    fi

    if ! ssh-add -l &>/dev/null || [[ ! -S "$AGENT_SOCKET" ]]; then
        restart_ssh_agent
    fi
}

restart_ssh_agent() {
    mkdir -p "$(dirname "$AGENT_SOCKET")" "$(dirname "$AGENT_INFO")"
    chmod 700 "$(dirname "$AGENT_SOCKET")" "$(dirname "$AGENT_INFO")"

    [[ -S "$AGENT_SOCKET" ]] && rm "$AGENT_SOCKET"

    echo "Starting new SSH agent..."
    ssh-agent -a "$AGENT_SOCKET" > "$AGENT_INFO"
    source "$AGENT_INFO"

    add_ssh_keys
}

add_ssh_keys() {
    local key_count=0
    for key in "$HOME/.ssh"/id_*; do
        [[ -f "$key" && "$key" != *.pub ]] || continue
        if ! ssh-add -l | grep -q "$(ssh-keygen -lf "$key" | awk '{print $2}')"; then
            ssh-add "$key" && ((key_count++))
        fi
    done
    echo "Added $key_count SSH key(s) to agent"
}

init_ssh() {
    # Fast path: 1Password agent present → skip agent-dir setup entirely
    if [[ -S "$ONEPASSWORD_SOCKET_MACOS" ]]; then
        export SSH_AUTH_SOCK="$ONEPASSWORD_SOCKET_MACOS"
        return
    elif [[ -S "$ONEPASSWORD_SOCKET_LINUX" ]]; then
        export SSH_AUTH_SOCK="$ONEPASSWORD_SOCKET_LINUX"
        return
    fi

    # No 1Password — fall back to managed ssh-agent. Use zsh :h modifier
    # instead of $(dirname ...) subshells.
    mkdir -p "${AGENT_SOCKET:h}" "${AGENT_INFO:h}"
    chmod 700 "${AGENT_SOCKET:h}" "${AGENT_INFO:h}"
    handle_ssh_agent
}

init_ssh

# SSH wrapper to auto-rename tmux windows to hostname
unalias ssh 2>/dev/null
ssh() {
    # Extract hostname from last arg; strip user@ prefix and rsync-style :/path
    local host="${@: -1}"
    host="${host#*@}"
    host="${host%%:*}"
    host="${host%%/*}"

    _tmux_title_wrap "🔐 $host" command ssh "$@"
}

# Sudo wrapper to warn about persistent root shells
unalias sudo 2>/dev/null
# Resolve the real sudo binary once — NixOS needs /run/wrappers/bin/sudo (setuid)
_sudo_bin="${commands[sudo]:-sudo}"
[[ -x /run/wrappers/bin/sudo ]] && _sudo_bin=/run/wrappers/bin/sudo
sudo() {
    local is_interactive=0 arg
    for arg in "$@"; do
        case "$arg" in -i|-s|su) is_interactive=1; break ;; esac
    done

    if [[ -z "$TMUX" || $is_interactive -eq 0 ]]; then
        $_sudo_bin "$@"
        return
    fi

    # Mark pane as root-owned — _tmux_title_pop clears it during wrap exit.
    tmux set-option -t "$(tmux display-message -p '#{pane_id}')" -p @is_root "1"
    _tmux_title_wrap "⚠️ ROOT" "$_sudo_bin" "$@"
}
