#!/bin/zsh

# Constants for styling
reset="[0m"
bold="[1m"
red="[31m"
green="[32m"
yellow="[33m"
blue="[34m"

# Update PS1 prompt
update_ps1() {
    local powerline_cmd

    if is_osx; then
        if is_arm; then
            powerline_cmd="$HOME/bin/powerline-go-darwin-arm64"
        else
            powerline_cmd="$HOME/bin/powerline-go-darwin-amd64"
        fi
    elif is_linux; then
        if is_arm; then
            powerline_cmd="$HOME/bin/powerline-go-linux-arm64"
        else
            powerline_cmd="$HOME/bin/powerline-go-linux-amd64"
        fi
    fi

    # Check if the powerline_cmd is executable
    if [[ -n "$powerline_cmd" ]] && [[ -x "$powerline_cmd" ]]; then
        PS1="$($powerline_cmd -error $? -jobs $(jobs -p | wc -l))"
    else
        PS1="[%n@%m %~]%# "
    fi
}

# Display system status and information
# Get gum path dynamically
get_gum_path() {
    local gum_path

    # First check if gum exists in PATH
    if command -v gum >/dev/null 2>&1; then
        gum_path=$(command -v gum)
    # Then check Homebrew location on macOS
    elif [[ -x "/opt/homebrew/bin/gum" ]]; then
        gum_path="/opt/homebrew/bin/gum"
    # Finally check common Linux location
    elif [[ -x "/usr/bin/gum" ]]; then
        gum_path="/usr/bin/gum"
    else
        echo ""
        return 1
    fi

    echo "$gum_path"
}

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
    local cpu_info=""
    local memory_info=""
    local memory_usage=""
    local cpu_cores=""
    local cpu_load=""

    # Start system info gathering in background with output redirection
    {
        case "$os_type" in
            OSX)
                cpu_info=$(sysctl -n machdep.cpu.brand_string)
                memory_info=$(($(sysctl -n hw.memsize) / 1024 / 1024))"MB"
                memory_usage=$(vm_stat | awk '
                    /Pages active/ {active=$3}
                    /Pages wired/ {wired=$3}
                    /Pages occupied/ {occupied=$3}
                    END {
                        used=(active + wired + occupied) * 4096
                        total='$(sysctl -n hw.memsize)'
                        printf "%.1f%%", used/total*100
                    }' | sed 's/\.0%/%/')
                cpu_cores=$(sysctl -n hw.ncpu)
                cpu_load=$(sysctl -n vm.loadavg | awk '{printf "%.1f", $2}')
                ;;
            LINUX)
                cpu_info=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | sed 's/^[ \t]*//')
                memory_info=$(($(grep MemTotal /proc/meminfo | awk '{print $2}') / 1024))"MB"
                memory_usage=$(free | awk '/Mem:/ {printf "%.1f%%", $3/$2 * 100}')
                cpu_cores=$(nproc)
                cpu_load=$(uptime | awk -F'[a-z]:' '{print $2}' | awk -F',' '{printf "%.1f", $1}')
                ;;
        esac

        # Store results in temporary files
        echo "$cpu_info" > /tmp/cpu_info.$$
        echo "$memory_info" > /tmp/memory_info.$$
        echo "$memory_usage" > /tmp/memory_usage.$$
        echo "$cpu_cores" > /tmp/cpu_cores.$$
        echo "$cpu_load" > /tmp/cpu_load.$$
    } >/dev/null 2>&1 &

    # Use gum_cmd for logo display
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

    # Wait for background process
    wait >/dev/null 2>&1

    # Read the gathered information
    cpu_info=$(cat /tmp/cpu_info.$$ 2>/dev/null)
    memory_info=$(cat /tmp/memory_info.$$ 2>/dev/null)
    memory_usage=$(cat /tmp/memory_usage.$$ 2>/dev/null)
    cpu_cores=$(cat /tmp/cpu_cores.$$ 2>/dev/null)
    cpu_load=$(cat /tmp/cpu_load.$$ 2>/dev/null)

    # Clean up temporary files
    rm -f /tmp/cpu_info.$$ /tmp/memory_info.$$ /tmp/memory_usage.$$ /tmp/cpu_cores.$$ /tmp/cpu_load.$$ 2>/dev/null

    # Display system information using gum_cmd
    "$gum_cmd" style \
        --width 70 \
        --border normal \
        --margin "1 0" \
        --padding "1" \
        "$("$gum_cmd" style --bold --foreground 212 'SYSTEM INFO')" \
        "$("$gum_cmd" style --foreground 99 "×þ System     [ $(uname -s) ]")" \
        "$("$gum_cmd" style --foreground 99 "×þ Platform   [ $os_type ]")" \
        "$("$gum_cmd" style --foreground 99 "×þ Arch       [ $arch_type ]")" \
        "$("$gum_cmd" style --foreground 99 "×þ Release    [ $(date +%Y-%m-%d) ]")" \
        "$("$gum_cmd" style --foreground 99 "×þ CPU        [ $cpu_info ]")" \
        "$("$gum_cmd" style --foreground 99 "×þ Cores      [ $cpu_cores ]")" \
        "$("$gum_cmd" style --foreground 99 "×þ Load       [ $cpu_load ]")" \
        "$("$gum_cmd" style --foreground 99 "×þ Memory     [ $memory_info ]")" \
        "$("$gum_cmd" style --foreground 99 "×þ Mem Usage  [ $memory_usage ]")"

    # Show recommendations if there are any issues
    if [[ "${memory_usage%\%}" -gt 90 || $(echo "$cpu_load > $cpu_cores" | bc -l) -eq 1 ]]; then
        "$gum_cmd" style \
            --width 70 \
            --border normal \
            --margin "1 0" \
            --padding "1" \
            "$("$gum_cmd" style --bold --foreground 212 'RECOMMENDATIONS')" \
            "$(provide_quick_recommendations)"
    fi
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
