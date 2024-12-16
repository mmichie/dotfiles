#!/bin/zsh

# Constants for SSH agent configuration
readonly AGENT_SOCKET="$HOME/.ssh/.ssh-agent-socket"
readonly AGENT_INFO="$HOME/.ssh/.ssh-agent-info"

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

    # Add default keys
    add_ssh_keys
}

# Add SSH keys to the agent
add_ssh_keys() {
    local ssh_dir="$HOME/.ssh"
    local key_count=0

    # Add all private keys that don't end in .pub
    for key in "$ssh_dir"/id_*; do
        if [[ -f "$key" && ! "$key" =~ \.pub$ ]]; then
            ssh-add "$key" && ((key_count++))
        fi
    done

    echo "Added $key_count SSH key(s) to agent"
}

# Get SSH agent status information
get_ssh_agent_status() {
    local status="Unknown"
    local pid=""
    local key_count=0

    if [[ -n "$SSH_AGENT_PID" ]]; then
        if ps -p "$SSH_AGENT_PID" >/dev/null; then
            status="Running"
            pid=$SSH_AGENT_PID
            key_count=$(ssh-add -l 2>/dev/null | grep -c "^[0-9]")
        else
            status="Dead (stale PID)"
        fi
    else
        status="Not running"
    fi

    cat <<EOF
SSH Agent Status:
  Status: $status
  PID: ${pid:-N/A}
  Socket: ${SSH_AUTH_SOCK:-N/A}
  Keys loaded: ${key_count}
EOF
}

# Kill the current SSH agent
kill_ssh_agent() {
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
        echo "No SSH agent running"
    fi
}

# Restart the SSH agent and reload keys
reload_ssh_agent() {
    kill_ssh_agent
    handle_ssh_agent
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
