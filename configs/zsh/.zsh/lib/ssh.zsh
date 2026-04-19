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
    mkdir -p "$(dirname "$AGENT_SOCKET")" "$(dirname "$AGENT_INFO")"
    chmod 700 "$(dirname "$AGENT_SOCKET")" "$(dirname "$AGENT_INFO")"
    handle_ssh_agent
}

init_ssh

# SSH wrapper to auto-rename tmux windows to hostname
unalias ssh 2>/dev/null
ssh() {
    if [[ -n "$TMUX" ]]; then
        # Capture window/pane ID at start to ensure cleanup targets correct window
        local window_id=$(tmux display-message -p '#{window_id}')
        local pane_id=$(tmux display-message -p '#{pane_id}')

        # Extract hostname from SSH args (last argument)
        local host="${@: -1}"
        # Strip user@ prefix if present
        host="${host#*@}"
        # Strip everything after : or / (for rsync-style paths)
        host="${host%%:*}"
        host="${host%%/*}"

        # Function to cleanup tmux custom title
        local cleanup() {
            tmux set-option -t "$pane_id" -p @custom_title ""
            tmux set-option -t "$window_id" -w @priority_title ""
            # Immediately update window title instead of waiting for precmd
            # This ensures title updates even if user is viewing a different pane
            local smart_title=$(_tmux_emoji_get_dir_title 2>/dev/null || echo "$(basename "$PWD")")
            tmux set-option -t "$pane_id" -p @dir_title "$smart_title"
            tmux rename-window -t "$window_id" "$smart_title"
            tmux set-window-option -t "$window_id" automatic-rename on
        }

        # Store custom title in tmux pane option AND window-level priority title (persists across pane switches)
        local title="🔐 $host"
        tmux set-option -t "$pane_id" -p @custom_title "$title"
        tmux set-option -t "$window_id" -w @priority_title "$title"
        tmux rename-window -t "$window_id" "$title"
        # Disable automatic-rename to prevent status-interval from overwriting with @dir_title
        tmux set-window-option -t "$window_id" automatic-rename off

        # Ensure cleanup happens even on timeout/interrupt
        trap cleanup INT TERM EXIT

        # Run SSH
        command ssh "$@"
        local exit_code=$?

        trap - INT TERM EXIT
        cleanup

        return $exit_code
    else
        command ssh "$@"
    fi
}

# Sudo wrapper to warn about persistent root shells
unalias sudo 2>/dev/null
# Resolve the real sudo binary once — NixOS needs /run/wrappers/bin/sudo (setuid)
_sudo_bin="${commands[sudo]:-sudo}"
[[ -x /run/wrappers/bin/sudo ]] && _sudo_bin=/run/wrappers/bin/sudo
sudo() {
    # Check if this is an interactive shell invocation
    local is_interactive=0
    for arg in "$@"; do
        if [[ "$arg" == "-i" ]] || [[ "$arg" == "-s" ]] || [[ "$arg" == "su" ]]; then
            is_interactive=1
            break
        fi
    done

    if [[ -n "$TMUX" ]] && [[ $is_interactive -eq 1 ]]; then
        # Capture window/pane ID at start to ensure cleanup targets correct window
        local window_id=$(tmux display-message -p '#{window_id}')
        local pane_id=$(tmux display-message -p '#{pane_id}')

        # Function to cleanup tmux root warning
        local cleanup() {
            tmux set-option -t "$pane_id" -p @is_root ""
            tmux set-option -t "$pane_id" -p @custom_title ""
            tmux set-option -t "$window_id" -w @priority_title ""
            # Immediately update window title instead of waiting for precmd
            # This ensures title updates even if user is viewing a different pane
            local smart_title=$(_tmux_emoji_get_dir_title 2>/dev/null || echo "$(basename "$PWD")")
            tmux set-option -t "$pane_id" -p @dir_title "$smart_title"
            tmux rename-window -t "$window_id" "$smart_title"
            tmux set-window-option -t "$window_id" automatic-rename on
        }

        # Set root warning marker and update window title immediately
        tmux set-option -t "$pane_id" -p @is_root "1"
        local title="⚠️ ROOT"
        tmux set-option -t "$pane_id" -p @custom_title "$title"
        tmux set-option -t "$window_id" -w @priority_title "$title"
        tmux rename-window -t "$window_id" "$title"
        # Disable automatic-rename to prevent status-interval from overwriting with @dir_title
        tmux set-window-option -t "$window_id" automatic-rename off

        # Ensure cleanup happens even on timeout/interrupt
        trap cleanup INT TERM EXIT

        # Run sudo
        $_sudo_bin "$@"
        local exit_code=$?

        trap - INT TERM EXIT
        cleanup

        return $exit_code
    else
        $_sudo_bin "$@"
    fi
}
