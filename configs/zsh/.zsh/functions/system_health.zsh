#!/bin/zsh

# ANSI styling constants (shared with prompt.zsh — redeclared here for lazy-load path)
typeset -g reset=$'\e[0m'
typeset -g bold=$'\e[1m'
typeset -g red=$'\e[31m'
typeset -g green=$'\e[32m'
typeset -g yellow=$'\e[33m'
typeset -g blue=$'\e[34m'

# Each check writes its result to $_HEALTH_TMP_DIR/<name>. display_system_health
# sets _HEALTH_TMP_DIR to a mktemp'd dir and cleans up. Standalone callers get
# /tmp as a fallback (same security posture as before this refactor).
_health_out() {
    echo "${_HEALTH_TMP_DIR:-/tmp}/$1"
}

# System information functions
check_system_load() {
    local load cores load_per_core

    if is_osx; then
        load=$(sysctl -n vm.loadavg | awk '{print $2}')
        cores=$(sysctl -n hw.ncpu)
    else
        load=$(uptime | awk -F'[a-z]:' '{ print $2 }' | awk -F',' '{print $1}' | tr -d ' ')
        cores=$(nproc 2>/dev/null || echo 1)
    fi

    load_per_core=$(echo "scale=2; $load / $cores" | bc -l 2>/dev/null)

    local out=$(_health_out load)
    if (( $(echo "$load_per_core > 1" | bc -l 2>/dev/null) )); then
        echo -e "  ${yellow}System Load:${reset} $load (${load_per_core} per core) ${red}(High load, investigate)${reset}" > "$out"
    else
        echo -e "  ${yellow}System Load:${reset} $load (${load_per_core} per core)" > "$out"
    fi
}

check_memory_usage() {
    local memory_usage total_memory

    if is_osx; then
        memory_usage=$(vm_stat | awk '/Pages active/ {print $3}' | sed 's/\.//')
        total_memory=$(sysctl hw.memsize | awk '{print $2}')
        memory_usage=$(echo "scale=2; $memory_usage * 4096 / $total_memory * 100" | bc -l 2>/dev/null)
    else
        memory_usage=$(free | awk '/Mem:/ {printf("%.2f", $3/$2 * 100.0)}')
    fi

    local out=$(_health_out memory)
    if (( $(echo "$memory_usage > 90" | bc -l 2>/dev/null) )); then
        echo -e "  ${yellow}Memory Usage:${reset} ${memory_usage}% ${red}(High usage, consider freeing up memory)${reset}" > "$out"
    else
        echo -e "  ${yellow}Memory Usage:${reset} ${memory_usage}%" > "$out"
    fi
}

check_disk_usage() {
    # command df: shell.zsh aliases df to duf, which doesn't accept -h
    local disk_usage=$(command df -h / | awk '/\// {print $(NF-1)}' | sed 's/%//')
    local out=$(_health_out disk)
    if (( disk_usage > 90 )); then
        echo -e "  ${yellow}Disk Usage:${reset} ${disk_usage}% ${red}(Low disk space, clean up files)${reset}" > "$out"
    else
        echo -e "  ${yellow}Disk Usage:${reset} ${disk_usage}%" > "$out"
    fi
}

check_ip_address() {
    local ip_address

    if is_osx; then
        ip_address=$(ipconfig getifaddr en0)
    elif is_linux; then
        ip_address=$(ip route get 1 | awk '{print $7; exit}')
    else
        ip_address="Unable to determine on this platform"
    fi

    echo -e "  ${yellow}IP Address:${reset} $ip_address" > "$(_health_out ip)"
}

check_last_login() {
    local last_login

    if is_osx; then
        last_login=$(last -1 $USER | awk 'NR==1 { print $4, $5, $6, $7 }')
    elif is_linux; then
        last_login=$(last -1 $USER | awk 'NR==1 {
            for (i=NF; i>0; i--) {
                if ($i ~ /:[0-9]+/) {
                    print $(i-3), $(i-2), $(i-1), $i
                    exit
                }
            }
            print $(NF-3), $(NF-2), $(NF-1), $NF
        }')
    else
        last_login="Unable to determine on this platform"
    fi

    echo -e "  ${yellow}Last Login:${reset} $last_login" > "$(_health_out login)"
}

check_uptime() {
    local uptime out=$(_health_out uptime)

    if is_osx; then
        local boot_time=$(sysctl -n kern.boottime | awk '{print $4}' | sed 's/,//g')
        local current_time=$(date +%s)
        uptime=$((current_time - boot_time))
    elif is_linux; then
        uptime=$(cat /proc/uptime | awk '{print $1}')
        uptime=${uptime%.*}
    else
        echo -e "  ${yellow}System Uptime:${reset} Unable to determine on this platform" > "$out"
        return
    fi

    local days=$((uptime / 86400))
    local hours=$(((uptime % 86400) / 3600))
    local minutes=$(((uptime % 3600) / 60))

    echo -e "  ${yellow}System Uptime:${reset} ${days} days, ${hours} hours, ${minutes} minutes" > "$out"
}

# Health check functions
check_cpu_temperature() {
    local out=$(_health_out cpu)
    if ! command -v osx-cpu-temp &>/dev/null; then
        echo -e "  ${yellow}CPU Temperature:${reset} N/A (install osx-cpu-temp)" > "$out"
        return
    fi
    # osx-cpu-temp output looks like "56.3°C" — strip non-numeric suffix for bc
    local raw=$(osx-cpu-temp)
    local temp=${raw%%[^0-9.]*}
    if [[ -n "$temp" ]] && (( $(echo "$temp > 80" | bc -l 2>/dev/null) )); then
        echo -e "  ${yellow}CPU Temperature:${reset} ${temp}°C ${red}(High temperature, check cooling)${reset}" > "$out"
    else
        echo -e "  ${yellow}CPU Temperature:${reset} ${temp:-unknown}°C" > "$out"
    fi
}

check_disk_health() {
    local disk_health=$(diskutil info disk0 | awk '/SMART Status/ {print $3}')
    local out=$(_health_out diskhealth)
    if [[ "$disk_health" != "Verified" ]]; then
        echo -e "  ${yellow}Disk Health:${reset} $disk_health ${red}(Potential disk issues, backup data)${reset}" > "$out"
    else
        echo -e "  ${yellow}Disk Health:${reset} $disk_health" > "$out"
    fi
}

check_network_status() {
    local ping_result=$(ping -c 1 8.8.8.8 2>&1 | awk '/time=/ {print $7}' | cut -d'=' -f2)
    local out=$(_health_out network)
    if [[ -n "$ping_result" ]]; then
        echo -e "  ${yellow}Network Status:${reset} Connected (Ping: ${ping_result}ms)" > "$out"
    else
        echo -e "  ${yellow}Network Status:${reset} ${red}Disconnected (Check network connection)${reset}" > "$out"
    fi
}

check_system_updates() {
    # command grep: shell.zsh aliases grep with --color=auto which injects ANSI into -c counts
    local updates=$(softwareupdate -l 2>&1 | command grep -c "No new software available.")
    local out=$(_health_out updates)
    if [[ "$updates" -eq 0 ]]; then
        echo -e "  ${yellow}System Updates:${reset} ${red}Updates available (Run softwareupdate)${reset}" > "$out"
    else
        echo -e "  ${yellow}System Updates:${reset} Up to date" > "$out"
    fi
}

check_security() {
    local firewall_status=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate | awk '{print $7}')
    local out=$(_health_out firewall)
    if [[ "$firewall_status" == "disabled" ]]; then
        echo -e "  ${yellow}Firewall Status:${reset} ${red}Disabled (Enable firewall for better security)${reset}" > "$out"
    else
        echo -e "  ${yellow}Firewall Status:${reset} Enabled" > "$out"
    fi
}

# Main function to display system health
display_system_health() {
    setopt local_options null_glob

    local fast_mode=${1:-0}

    # Secure per-invocation tempdir; forked background checks inherit via env
    local _HEALTH_TMP_DIR=$(mktemp -d -t system_health.XXXXXX)
    trap "rm -rf '$_HEALTH_TMP_DIR'" EXIT INT TERM

    # Core checks run everywhere
    local -a checks=(check_system_load check_memory_usage check_disk_usage)

    if [[ "$fast_mode" -ne 1 ]]; then
        checks+=(check_ip_address check_last_login check_uptime check_network_status)
        # macOS-only checks (use diskutil, softwareupdate, socketfilterfw, osx-cpu-temp)
        is_osx && checks+=(check_cpu_temperature check_disk_health check_system_updates check_security)
    fi

    local check
    for check in "${checks[@]}"; do "$check" &; done
    wait

    gum style \
        --width 70 \
        --border double \
        --margin "1" \
        --padding "1" \
        --foreground 212 \
        "System Health Report"

    # command cat: shell.zsh aliases cat to bat which mangles embedded ANSI color codes
    local file
    for file in "$_HEALTH_TMP_DIR"/*; do
        [[ -f "$file" ]] && command cat "$file"
    done

    provide_recommendations "$_HEALTH_TMP_DIR"

    trap - EXIT INT TERM
    rm -rf "$_HEALTH_TMP_DIR"
}

provide_recommendations() {
    local dir="$1"
    local recommendations=()

    local memory_usage=$(awk '{print $3}' "$dir/memory" 2>/dev/null | sed 's/%//')
    if [[ -n "$memory_usage" ]] && (( $(echo "$memory_usage > 90" | bc -l 2>/dev/null) )); then
        recommendations+=("- Consider closing unnecessary applications to free up memory.")
    fi

    local disk_usage=$(awk '{print $3}' "$dir/disk" 2>/dev/null | sed 's/%//')
    if [[ -n "$disk_usage" ]] && (( disk_usage > 90 )); then
        recommendations+=("- Clean up unnecessary files or consider upgrading disk space.")
    fi

    if command grep -q "Updates available" "$dir/updates" 2>/dev/null; then
        recommendations+=("- Install available system updates to improve security and performance.")
    fi

    if command grep -q "Disabled" "$dir/firewall" 2>/dev/null; then
        recommendations+=("- Enable the system firewall to enhance security.")
    fi

    if [[ ${#recommendations[@]} -gt 0 ]]; then
        echo ""
        gum style \
            --border normal \
            --margin "1 0" \
            --padding "1" \
            "$(gum style --bold --foreground 212 'RECOMMENDATIONS')"
        printf "%s\n" "${recommendations[@]}"
    fi
}
