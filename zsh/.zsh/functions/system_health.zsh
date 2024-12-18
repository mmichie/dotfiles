#!/bin/zsh

# Constants for styling
reset="[0m"
bold="[1m"
red="[31m"
green="[32m"
yellow="[33m"
blue="[34m"

# System information functions
check_system_load() {
    local load
    local cores
    local load_per_core

    if is_osx; then
        load=$(sysctl -n vm.loadavg | awk '{print $2}')
        cores=$(sysctl -n hw.ncpu)
    else
        load=$(uptime | awk -F'[a-z]:' '{ print $2 }' | awk -F',' '{print $1}' | tr -d ' ')
        cores=$(nproc 2>/dev/null || echo 1)
    fi

    load_per_core=$(echo "scale=2; $load / $cores" | bc -l 2>/dev/null)

    if (( $(echo "$load_per_core > 1" | bc -l 2>/dev/null) )); then
        echo -e "  ${yellow}System Load:${reset} $load (${load_per_core} per core) ${red}(High load, investigate)${reset}" > /tmp/system_info_load
    else
        echo -e "  ${yellow}System Load:${reset} $load (${load_per_core} per core)" > /tmp/system_info_load
    fi
}

check_memory_usage() {
    local memory_usage
    local total_memory

    if is_osx; then
        memory_usage=$(vm_stat | awk '/Pages active/ {print $3}' | sed 's/\.//')
        total_memory=$(sysctl hw.memsize | awk '{print $2}')
        memory_usage=$(echo "scale=2; $memory_usage * 4096 / $total_memory * 100" | bc -l 2>/dev/null)
    else
        memory_usage=$(free | awk '/Mem:/ {printf("%.2f", $3/$2 * 100.0)}')
    fi

    if (( $(echo "$memory_usage > 90" | bc -l 2>/dev/null) )); then
        echo -e "  ${yellow}Memory Usage:${reset} ${memory_usage}% ${red}(High usage, consider freeing up memory)${reset}" > /tmp/system_info_memory
    else
        echo -e "  ${yellow}Memory Usage:${reset} ${memory_usage}%" > /tmp/system_info_memory
    fi
}

check_disk_usage() {
    local disk_usage=$(df -h / | awk '/\// {print $(NF-1)}' | sed 's/%//')
    if (( disk_usage > 90 )); then
        echo -e "  ${yellow}Disk Usage:${reset} ${disk_usage}% ${red}(Low disk space, clean up files)${reset}" > /tmp/system_info_disk
    else
        echo -e "  ${yellow}Disk Usage:${reset} ${disk_usage}%" > /tmp/system_info_disk
    fi
}

check_ip_address() {
    local os_type=$(detect_shell_platform)
    local ip_address

    if [[ "$os_type" == "OSX" ]]; then
        ip_address=$(ipconfig getifaddr en0)
    elif [[ "$os_type" == "LINUX" ]]; then
        ip_address=$(ip route get 1 | awk '{print $7; exit}')
    else
        ip_address="Unable to determine on this platform"
    fi

    echo -e "  ${yellow}IP Address:${reset} $ip_address" > /tmp/system_info_ip
}

check_last_login() {
    local os_type=$(detect_shell_platform)
    local last_login

    if [[ "$os_type" == "OSX" ]]; then
        last_login=$(last -1 $USER | awk 'NR==1 { print $4, $5, $6, $7 }')
    elif [[ "$os_type" == "LINUX" ]]; then
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

    echo -e "  ${yellow}Last Login:${reset} $last_login" > /tmp/system_info_login
}

check_uptime() {
    local os_type=$(detect_shell_platform)
    local uptime_str

    case "$os_type" in
        OSX)
            local boot_time=$(sysctl -n kern.boottime | awk '{print $4}' | sed 's/,//g')
            local current_time=$(date +%s)
            local uptime=$((current_time - boot_time))
            ;;
        LINUX)
            local uptime=$(cat /proc/uptime | awk '{print $1}')
            uptime=${uptime%.*}  # Remove decimal part
            ;;
        *)
            echo -e "  ${yellow}System Uptime:${reset} Unable to determine on this platform" > /tmp/system_info_uptime
            return
            ;;
    esac

    local days=$((uptime / 86400))
    local hours=$(((uptime % 86400) / 3600))
    local minutes=$(((uptime % 3600) / 60))

    echo -e "  ${yellow}System Uptime:${reset} ${days} days, ${hours} hours, ${minutes} minutes" > /tmp/system_info_uptime
}

# Health check functions
check_cpu_temperature() {
    local temp
    if command -v osx-cpu-temp &> /dev/null; then
        temp=$(osx-cpu-temp | awk '{print $1}')
    else
        temp="N/A (install osx-cpu-temp)"
    fi
    if (( $(echo "$temp > 80" | bc -l 2>/dev/null) )); then
        echo -e "  ${yellow}CPU Temperature:${reset} ${temp}°C ${red}(High temperature, check cooling)${reset}" > /tmp/health_check_cpu
    else
        echo -e "  ${yellow}CPU Temperature:${reset} ${temp}°C" > /tmp/health_check_cpu
    fi
}

check_disk_health() {
    local disk_health=$(diskutil info disk0 | awk '/SMART Status/ {print $3}')
    if [[ "$disk_health" != "Verified" ]]; then
        echo -e "  ${yellow}Disk Health:${reset} $disk_health ${red}(Potential disk issues, backup data)${reset}" > /tmp/health_check_disk
    else
        echo -e "  ${yellow}Disk Health:${reset} $disk_health" > /tmp/health_check_disk
    fi
}

check_network_status() {
    local ping_result=$(ping -c 1 8.8.8.8 2>&1 | awk '/time=/ {print $7}' | cut -d'=' -f2)
    if [[ -n "$ping_result" ]]; then
        echo -e "  ${yellow}Network Status:${reset} Connected (Ping: ${ping_result}ms)" > /tmp/health_check_network
    else
        echo -e "  ${yellow}Network Status:${reset} ${red}Disconnected (Check network connection)${reset}" > /tmp/health_check_network
    fi
}

check_system_updates() {
    local updates=$(softwareupdate -l 2>&1 | grep -c "No new software available.")
    if [[ "$updates" -eq 0 ]]; then
        echo -e "  ${yellow}System Updates:${reset} ${red}Updates available (Run softwareupdate)${reset}" > /tmp/health_check_updates
    else
        echo -e "  ${yellow}System Updates:${reset} Up to date" > /tmp/health_check_updates
    fi
}

check_security() {
    local firewall_status=$(/usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate | awk '{print $7}')
    if [[ "$firewall_status" == "disabled" ]]; then
        echo -e "  ${yellow}Firewall Status:${reset} ${red}Disabled (Enable firewall for better security)${reset}" > /tmp/health_check_firewall
    else
        echo -e "  ${yellow}Firewall Status:${reset} Enabled" > /tmp/health_check_firewall
    fi
}

# Main function to display system health
display_system_health() {
    # Run all checks in parallel
    check_system_load &
    check_memory_usage &
    check_disk_usage &
    check_ip_address &
    check_last_login &
    check_uptime &
    check_cpu_temperature &
    check_disk_health &
    check_network_status &
    check_system_updates &
    check_security &

    # Wait for all background processes to complete
    wait

    # Display system information
    gum style \
        --width 70 \
        --border double \
        --margin "1" \
        --padding "1" \
        --foreground 212 \
        "System Health Report"

    # Display information from temporary files
    for file in /tmp/{system_info,health_check}_*; do
        if [[ -f "$file" ]]; then
            cat "$file"
            rm "$file"
        fi
    done

    # Show recommendations if there are any issues
    provide_recommendations
}

provide_recommendations() {
    local recommendations=()

    # Check for high memory usage
    local memory_usage=$(cat /tmp/system_info_memory 2>/dev/null | awk '{print $3}' | sed 's/%//')
    if [[ -n "$memory_usage" ]] && (( $(echo "$memory_usage > 90" | bc -l 2>/dev/null) )); then
        recommendations+=("- Consider closing unnecessary applications to free up memory.")
    fi

    # Check for high disk usage
    local disk_usage=$(cat /tmp/system_info_disk 2>/dev/null | awk '{print $3}' | sed 's/%//')
    if [[ -n "$disk_usage" ]] && (( disk_usage > 90 )); then
        recommendations+=("- Clean up unnecessary files or consider upgrading disk space.")
    fi

    # Check for system updates
    if grep -q "Updates available" /tmp/health_check_updates 2>/dev/null; then
        recommendations+=("- Install available system updates to improve security and performance.")
    fi

    # Check for disabled firewall
    if grep -q "Disabled" /tmp/health_check_firewall 2>/dev/null; then
        recommendations+=("- Enable the system firewall to enhance security.")
    fi

    # Display recommendations if any exist
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
