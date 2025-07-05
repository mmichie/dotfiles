#!/bin/zsh

# Constants for styling
reset="[0m"
bold="[1m"
red="[31m"
green="[32m"
yellow="[33m"
blue="[34m"

# Cache the powerline-go path
_cached_powerline_cmd=""

# Detect the appropriate powerline command only once
_detect_powerline_cmd() {
    if [[ -z "$_cached_powerline_cmd" ]]; then
        if is_osx; then
            if is_arm; then
                _cached_powerline_cmd="$HOME/bin/powerline-go-darwin-arm64"
            else
                _cached_powerline_cmd="$HOME/bin/powerline-go-darwin-amd64"
            fi
        elif is_linux; then
            if is_arm; then
                _cached_powerline_cmd="$HOME/bin/powerline-go-linux-arm64"
            else
                _cached_powerline_cmd="$HOME/bin/powerline-go-linux-amd64"
            fi
        fi
        
        # If not executable, set to empty
        if [[ -n "$_cached_powerline_cmd" ]] && [[ ! -x "$_cached_powerline_cmd" ]]; then
            _cached_powerline_cmd=""
        fi
    fi
}

# Initialize powerline command on load
_detect_powerline_cmd

# Update PS1 prompt
update_ps1() {
    # Check if the powerline_cmd is available
    if [[ -n "$_cached_powerline_cmd" ]]; then
        PS1="$($_cached_powerline_cmd -error $? -jobs $(jobs -p | wc -l))"
    else
        PS1="[%n@%m %~]%# "
    fi
}

# Display system status and information
# Get gum path dynamically
# Display system status and information
notify_shell_status() {
    # Get gum path
    local gum_cmd=$(get_gum_path)

    if [[ -z "$gum_cmd" ]]; then
        echo "Warning: gum command not found. Please ensure it's installed and in your PATH."
        return 1
    fi

    # Temporarily disable job notifications
    setopt local_options NO_NOTIFY NO_MONITOR

    # Get platform info first since we need it immediately
    local os_type="$SYSTEM_OS_TYPE"
    local arch_type="$SYSTEM_ARCH"
    
    # Use optimized/simplified display for better performance
    "$gum_cmd" style \
        --align center \
        --width 70 \
        --border double \
        --margin "1" \
        --padding "1" \
        --foreground 212 \
"░▒▓█▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀█▓▒░
░▒▓█  ▄█ █▄  █ ▄▀▀▀▀█ █      █   █ ▀▄  ▄▀  █▓▒░
░▒▓█   █ █ █ █ █▄▄▄▄  █      █   █  ▀▄▄▀   █▓▒░
░▒▓█   █ █ █ █ █      █      █   █   ▄▀▄   █▓▒░
░▒▓█  ▄█ █  ██ █      █▄▄▄▄  █▄▄▄█ ▄▀  ▀▄  █▓▒░
░▒▓█▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄█▓▒░
  ╔═-» [ Terminal Underground Division ] «-═╗
  ║    [×] proudly serving the scene [×]    ║
  ╚════-» [ fido.net.scene.2024.MAIN ] «-═══╝" \
      "$("$gum_cmd" style --foreground 99 'DISTRIBUTION NODE: 4:920/35')"

    # Get minimal system info quickly
    local system_name=$(uname -s)
    local date_info=$(date +%Y-%m-%d)
    local load_info=""
    local memory_info=""
    
    if is_osx; then
        load_info=$(sysctl -n vm.loadavg | awk '{printf "%.1f", $2}')
        memory_info=$(($(sysctl -n hw.memsize) / 1024 / 1024 / 1024))"GB"
    elif is_linux; then
        load_info=$(uptime | awk -F'[a-z]:' '{print $2}' | awk -F',' '{printf "%.1f", $1}')
        memory_info=$(($(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024 / 1024))"GB"
    fi

    # Display simplified system information
    "$gum_cmd" style \
        --width 70 \
        --border normal \
        --margin "1 0" \
        --padding "1" \
        "$("$gum_cmd" style --bold --foreground 212 'SYSTEM INFO')" \
        "$("$gum_cmd" style --foreground 99 "×þ System     [ $system_name ]")" \
        "$("$gum_cmd" style --foreground 99 "×þ Platform   [ $os_type ]")" \
        "$("$gum_cmd" style --foreground 99 "×þ Arch       [ $arch_type ]")" \
        "$("$gum_cmd" style --foreground 99 "×þ Date       [ $date_info ]")" \
        "$("$gum_cmd" style --foreground 99 "×þ Load       [ $load_info ]")" \
        "$("$gum_cmd" style --foreground 99 "×þ Memory     [ $memory_info ]")"
}

# Helper function for system recommendations
provide_quick_recommendations() {
    local recommendations=()

    if [[ "${memory_usage%\%}" -gt 90 ]]; then
        recommendations+=("- High memory usage detected. Consider closing unnecessary applications.")
    fi

    if [[ $(echo "$cpu_load > $cpu_cores" | bc -l) -eq 1 ]]; then
        recommendations+=("- High CPU load detected. Check for resource-intensive processes.")
    fi

    if [[ ${#recommendations[@]} -gt 0 ]]; then
        printf "%s\n" "${recommendations[@]}"
    else
        echo "  Your system appears to be in good health. No specific recommendations at this time."
    fi
}

# OSC 7 directory tracking
osc7_cwd() {
    local hostname=${HOST:-$(hostname)}
    local url="file://${hostname}${PWD}"
    printf '\e]7;%s\a' "${url}"
}

# Initialize prompt
init_prompt() {
    # Set up precmd hooks only once
    autoload -Uz add-zsh-hook
    add-zsh-hook precmd osc7_cwd
    [[ $TERM == (xterm*|screen*) ]] && add-zsh-hook precmd update_ps1
}
