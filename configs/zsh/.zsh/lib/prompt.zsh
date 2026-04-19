#!/bin/zsh

# ANSI styling constants (module-scoped via typeset -g so they don't leak unquoted)
typeset -g reset=$'\e[0m'
typeset -g bold=$'\e[1m'
typeset -g red=$'\e[31m'
typeset -g green=$'\e[32m'
typeset -g yellow=$'\e[33m'
typeset -g blue=$'\e[34m'

# Initialize plx prompt
_init_plx() {
    eval "$(plx init zsh)"
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
    
    # Generate and display banner (kitty graphics protocol, no chafa needed)
    if command -v plx &>/dev/null; then
        plx banner 2
    else
        generate_login_banner

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
    _init_plx
}
