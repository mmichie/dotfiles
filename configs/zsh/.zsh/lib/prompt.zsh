#!/bin/zsh

# Constants for styling
reset="[0m"
bold="[1m"
red="[31m"
green="[32m"
yellow="[33m"
blue="[34m"

# Initialize starship prompt
_init_starship() {
    if command -v starship &>/dev/null; then
        eval "$(starship init zsh)"
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
    _init_starship
}
