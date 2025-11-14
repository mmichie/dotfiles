#!/bin/zsh

# Constants for SSH agent configuration
readonly AGENT_SOCKET="$HOME/.ssh/.ssh-agent-socket"
readonly AGENT_INFO="$HOME/.ssh/.ssh-agent-info"
readonly ONEPASSWORD_SOCKET="$HOME/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

# List of hostnames where SSH agent should be started
readonly SSH_HOSTNAMES=(
    "mattmichie-mbp"
    "matt-pc"
    "miley"
    "matt-pc-wsl"
)

# Checks if the current hostname is in the list of SSH hostnames
is_ssh_host() {
    local current_host=$(hostname)
    [[ " ${SSH_HOSTNAMES[*]} " == *" ${current_host} "* ]]
}

# Handles the initialization and maintenance of an SSH agent
handle_ssh_agent() {
    # Skip if not on a designated SSH host
    is_ssh_host || return 0

    # First try to use 1Password SSH agent
    if [[ -S "$ONEPASSWORD_SOCKET" ]]; then
        export SSH_AUTH_SOCK="$ONEPASSWORD_SOCKET"
        return 0
    fi

    # Fall back to traditional SSH agent if 1Password is not available
    # Load existing agent configuration if available
    if [[ -s "$AGENT_INFO" ]]; then
        source "$AGENT_INFO"
    fi

    # Check if SSH agent needs restarting
    if ! ssh-add -l &>/dev/null || [[ ! -S "$AGENT_SOCKET" ]]; then
        restart_ssh_agent
    fi
}

# Restarts the SSH agent and updates the agent information files
restart_ssh_agent() {
    # Ensure the .ssh directory exists with proper permissions
    mkdir -p "$(dirname "$AGENT_SOCKET")" "$(dirname "$AGENT_INFO")"
    chmod 700 "$(dirname "$AGENT_SOCKET")" "$(dirname "$AGENT_INFO")"

    # Clean up old socket if it exists
    [[ -S "$AGENT_SOCKET" ]] && rm "$AGENT_SOCKET"

    # Start new SSH agent
    echo "Starting new SSH agent..."
    ssh-agent -a "$AGENT_SOCKET" > "$AGENT_INFO"

    # Load the new agent configuration
    source "$AGENT_INFO"

    # Add default keys and store in keychain
    add_ssh_keys
}

# Add SSH keys to the agent
add_ssh_keys() {
    local ssh_dir="$HOME/.ssh"
    local key_count=0

    # Add all private keys that don't end in .pub
    for key in "$ssh_dir"/id_*; do
        if [[ -f "$key" ]] && [[ "$key" != *.pub ]]; then
            # Skip if key is already added
            if ! ssh-add -l | grep -q "$(ssh-keygen -lf "$key" | awk '{print $2}')"; then
                # Add key and store in keychain on macOS
                if [[ "$(uname)" == "Darwin" ]]; then
                    ssh-add -K "$key" && ((key_count++))
                else
                    ssh-add "$key" && ((key_count++))
                fi
            fi
        fi
    done

    echo "Added $key_count SSH key(s) to agent"
}

# Get SSH agent status information
get_ssh_agent_status() {
    local agent_status="Unknown"
    local pid=""
    local key_count=0
    local socket_path=${SSH_AUTH_SOCK:-"N/A"}

    if [[ -S "$ONEPASSWORD_SOCKET" ]] && [[ "$SSH_AUTH_SOCK" == "$ONEPASSWORD_SOCKET" ]]; then
        agent_status="Using 1Password SSH Agent"
        socket_path="$ONEPASSWORD_SOCKET"
        key_count=$(ssh-add -l 2>/dev/null | grep -c "^[0-9]")
    elif [[ -n "$SSH_AGENT_PID" ]]; then
        if ps -p "$SSH_AGENT_PID" >/dev/null; then
            agent_status="Running (Traditional SSH Agent)"
            pid=$SSH_AGENT_PID
            key_count=$(ssh-add -l 2>/dev/null | grep -c "^[0-9]")
        else
            agent_status="Dead (stale PID)"
        fi
    else
        agent_status="Not running"
    fi

    cat <<EOF
SSH Agent Status:
  Status: $agent_status
  PID: ${pid:-N/A}
  Socket: $socket_path
  Keys loaded: ${key_count}
EOF
}

# Kill the current SSH agent (only if using traditional agent)
kill_ssh_agent() {
    if [[ "$SSH_AUTH_SOCK" == "$ONEPASSWORD_SOCKET" ]]; then
        echo "Using 1Password SSH agent - no need to kill"
        return 0
    fi

    if [[ -n "$SSH_AGENT_PID" ]]; then
        echo "Killing SSH agent (PID: $SSH_AGENT_PID)..."
        kill "$SSH_AGENT_PID"

        # Clean up files
        rm -f "$AGENT_SOCKET" "$AGENT_INFO"

        # Clear environment variables
        unset SSH_AGENT_PID
        unset SSH_AUTH_SOCK

        echo "SSH agent terminated"
    else
        echo "No traditional SSH agent running"
    fi
}

# Initialize SSH agent handling
init_ssh() {
    # Create required directories if they don't exist
    mkdir -p "$(dirname "$AGENT_SOCKET")" "$(dirname "$AGENT_INFO")"
    chmod 700 "$(dirname "$AGENT_SOCKET")" "$(dirname "$AGENT_INFO")"

    # Set up the SSH agent if on a designated host
    handle_ssh_agent
}

# Call initialization when the file is sourced
init_ssh

# SSH wrapper to auto-rename tmux windows to hostname
unalias ssh 2>/dev/null
ssh() {
    if [[ -n "$TMUX" ]]; then
        # Extract hostname from SSH args (last argument)
        local host="${@: -1}"
        # Strip user@ prefix if present
        host="${host#*@}"
        # Strip everything after : or / (for rsync-style paths)
        host="${host%%:*}"
        host="${host%%/*}"

        # Function to cleanup tmux window name
        local cleanup() {
            tmux rename-window ""
            tmux set-window-option automatic-rename on
        }

        # Rename tmux window
        tmux rename-window "🔐 $host"

        # Ensure cleanup happens even on timeout/interrupt
        trap cleanup INT TERM EXIT
        command ssh "$@"
        local exit_code=$?
        trap - INT TERM EXIT

        # Restore automatic renaming and clear the custom name
        cleanup

        return $exit_code
    else
        command ssh "$@"
    fi
}
