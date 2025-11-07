#!/usr/bin/env zsh

# Location CLI - User-facing commands for location service management

# Show current location status
location_status() {
    local db="${LOCATION_DB:-$HOME/.cache/shell/location.db}"

    if [[ ! -f "$db" ]]; then
        echo "Location database not initialized"
        return 1
    fi

    echo "=== Location Service Status ==="
    echo

    # Current location
    local current=$(sqlite3 "$db" "SELECT updated_at, ssid, bssid, ip_address, lat, lon, city, source, source_detail FROM current_location WHERE id = 1;" 2>/dev/null)

    if [[ -n "$current" ]]; then
        local updated_at ssid bssid ip lat lon city source source_detail
        IFS='|' read -r updated_at ssid bssid ip lat lon city source source_detail <<< "$current"

        local now=$(date +%s)
        local age=$((now - updated_at))
        local age_human

        if [[ $age -lt 60 ]]; then
            age_human="${age}s ago"
        elif [[ $age -lt 3600 ]]; then
            age_human="$((age / 60))m ago"
        else
            age_human="$((age / 3600))h ago"
        fi

        echo "Current Location:"
        echo "  Coordinates: $lat, $lon"
        [[ -n "$city" ]] && echo "  City: $city"
        echo "  Source: $source ($source_detail)"
        [[ -n "$ssid" ]] && echo "  WiFi: $ssid"
        [[ -n "$bssid" ]] && echo "  BSSID: $bssid"
        [[ -n "$ip" ]] && echo "  IP: $ip"
        echo "  Updated: $(date -r $updated_at '+%Y-%m-%d %H:%M:%S') ($age_human)"
        echo

        # Staleness check
        local update_interval=${LOCATION_UPDATE_INTERVAL:-300}
        if [[ $age -gt $update_interval ]]; then
            echo "  Status: ⚠️  STALE (will update on next command)"
        else
            echo "  Status: ✓ Fresh"
        fi
    else
        echo "No location data available"
        echo "Run 'location_force' to initialize"
    fi

    echo
    echo "Database: $db"
    echo "Update interval: ${LOCATION_UPDATE_INTERVAL:-300}s"

    # Statistics
    local network_count=$(sqlite3 "$db" "SELECT COUNT(*) FROM known_networks;" 2>/dev/null)
    echo "Known networks: $network_count"
}

# Show location history
location_history() {
    local db="${LOCATION_DB:-$HOME/.cache/shell/location.db}"
    local limit=${1:-10}

    if [[ ! -f "$db" ]]; then
        echo "Location database not initialized"
        return 1
    fi

    echo "=== Recent Location History ==="
    echo

    sqlite3 -column -header "$db" <<EOF
SELECT
  datetime(timestamp, 'unixepoch', 'localtime') as time,
  ssid,
  city,
  printf('%.4f, %.4f', lat, lon) as coordinates,
  source
FROM location_history
ORDER BY timestamp DESC
LIMIT $limit;
EOF
}

# Show known WiFi networks
location_networks() {
    local db="${LOCATION_DB:-$HOME/.cache/shell/location.db}"

    if [[ ! -f "$db" ]]; then
        echo "Location database not initialized"
        return 1
    fi

    echo "=== Known WiFi Networks ==="
    echo

    sqlite3 -column -header "$db" <<EOF
SELECT
  ssid,
  bssid,
  city,
  printf('%.4f, %.4f', lat, lon) as coordinates,
  source,
  times_seen,
  datetime(last_seen, 'unixepoch', 'localtime') as last_seen
FROM known_networks
ORDER BY last_seen DESC;
EOF
}

# Learn current network
location_learn() {
    local db="${LOCATION_DB:-$HOME/.cache/shell/location.db}"

    if [[ ! -f "$db" ]]; then
        echo "Location database not initialized"
        return 1
    fi

    # Get current location
    local current=$(sqlite3 "$db" "SELECT ssid, bssid, lat, lon, city, region, country_code FROM current_location WHERE id = 1;" 2>/dev/null)

    if [[ -z "$current" ]]; then
        echo "No current location to learn"
        return 1
    fi

    local ssid bssid lat lon city region country
    IFS='|' read -r ssid bssid lat lon city region country <<< "$current"

    if [[ -z "$ssid" ]]; then
        echo "Not connected to WiFi"
        return 1
    fi

    # Escape single quotes
    ssid="${ssid//\'/\'\'}"
    city="${city//\'/\'\'}"
    region="${region//\'/\'\'}"

    local now=$(date +%s)

    # Normalize empty bssid to empty string
    [[ -z "$bssid" ]] && bssid=""

    # Insert or update known network
    sqlite3 "$db" <<EOF
INSERT INTO known_networks (
  ssid, bssid, lat, lon, city, region, country_code,
  confidence, source, first_seen, last_seen, times_seen
)
VALUES (
  '$ssid', '$bssid', $lat, $lon, '$city', '$region', '$country',
  1.0, 'learned', $now, $now, 1
)
ON CONFLICT(ssid, bssid) DO UPDATE SET
  last_seen = $now,
  times_seen = times_seen + 1;
EOF

    echo "Learned network: $ssid"
    [[ -n "$bssid" ]] && echo "  BSSID: $bssid"
    echo "  Location: $city ($lat, $lon)"
}

# Export networks to config file
location_export() {
    local db="${LOCATION_DB:-$HOME/.cache/shell/location.db}"
    local output="${1:-$HOME/.config/clima/wifi-locations.conf}"

    if [[ ! -f "$db" ]]; then
        echo "Location database not initialized"
        return 1
    fi

    mkdir -p "$(dirname "$output")"

    {
        echo "# WiFi Location Configuration"
        echo "# Exported: $(date)"
        echo "# Format: SSID,latitude,longitude"
        echo

        sqlite3 "$db" <<EOF
SELECT ssid || ',' || lat || ',' || lon
FROM known_networks
WHERE bssid IS NULL OR bssid = ''
ORDER BY last_seen DESC;
EOF
    } > "$output"

    echo "Exported known networks to: $output"
}

# Import networks from config file
location_import() {
    local config="${1:-$HOME/.config/clima/wifi-locations.conf}"

    if [[ ! -f "$config" ]]; then
        echo "Config file not found: $config"
        return 1
    fi

    _location_import_config "$config"
    echo "Imported networks from: $config"
}

# Show database info
location_info() {
    local db="${LOCATION_DB:-$HOME/.cache/shell/location.db}"

    if [[ ! -f "$db" ]]; then
        echo "Location database not initialized"
        return 1
    fi

    echo "=== Location Database Info ==="
    echo

    echo "Database: $db"
    echo "Size: $(du -h "$db" | awk '{print $1}')"
    echo

    local version=$(sqlite3 "$db" "SELECT value FROM config WHERE key = 'version';" 2>/dev/null)
    echo "Schema version: $version"
    echo

    local history_count=$(sqlite3 "$db" "SELECT COUNT(*) FROM location_history;" 2>/dev/null)
    local network_count=$(sqlite3 "$db" "SELECT COUNT(*) FROM known_networks;" 2>/dev/null)

    echo "Statistics:"
    echo "  Location history: $history_count records"
    echo "  Known networks: $network_count networks"
    echo

    echo "Configuration:"
    sqlite3 -column -header "$db" "SELECT key, value FROM config ORDER BY key;" 2>/dev/null
}

# Main location command dispatcher
location() {
    local subcommand=${1:-status}
    shift

    case "$subcommand" in
        status)     location_status "$@" ;;
        history)    location_history "$@" ;;
        networks)   location_networks "$@" ;;
        learn)      location_learn "$@" ;;
        export)     location_export "$@" ;;
        import)     location_import "$@" ;;
        info)       location_info "$@" ;;
        update)     location_update "$@" ;;
        force)      location_force "$@" ;;
        get)        location_get "$@" ;;
        help)
            cat <<EOF
Location Service CLI

Usage: location <command> [arguments]

Commands:
  status              Show current location status
  history [limit]     Show recent location history (default: 10)
  networks            Show known WiFi networks
  learn               Learn current WiFi network location
  export [file]       Export networks to config file
  import [file]       Import networks from config file
  info                Show database information
  update              Update location if stale
  force               Force immediate location update
  get                 Get current location (lat lon source timestamp)
  help                Show this help message

Environment Variables:
  LOCATION_DB                 Database path (default: ~/.cache/shell/location.db)
  LOCATION_UPDATE_INTERVAL    Update interval in seconds (default: 300)
  LOCATION_STALE_THRESHOLD    Stale threshold in seconds (default: 900)
  DISABLE_WIFI_LOCATION       Disable automatic location updates

Examples:
  location status             # Show current location
  location history 20         # Show last 20 locations
  location learn              # Save current WiFi network
  location force              # Update location now
EOF
            ;;
        *)
            echo "Unknown command: $subcommand"
            echo "Run 'location help' for usage"
            return 1
            ;;
    esac
}

# Auto-complete for location command
_location_completion() {
    local -a commands
    commands=(
        'status:Show current location status'
        'history:Show recent location history'
        'networks:Show known WiFi networks'
        'learn:Learn current WiFi network location'
        'export:Export networks to config file'
        'import:Import networks from config file'
        'info:Show database information'
        'update:Update location if stale'
        'force:Force immediate location update'
        'get:Get current location'
        'help:Show help message'
    )
    _describe 'location command' commands
}

# Only set up completion if compdef is available
if command -v compdef >/dev/null 2>&1; then
    compdef _location_completion location
fi
