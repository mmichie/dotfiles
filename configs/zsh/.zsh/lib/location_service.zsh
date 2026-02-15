#!/usr/bin/env zsh

# Shell Location Service
# Provides network-aware geographic location with SQLite persistence
# Used by tmux-clima and other location-aware tools

# Configuration
LOCATION_DB="${LOCATION_DB:-$HOME/.cache/shell/location.db}"
LOCATION_SCHEMA="${LOCATION_SCHEMA:-$HOME/.config/location/schema.sql}"
LOCATION_UPDATE_INTERVAL="${LOCATION_UPDATE_INTERVAL:-300}"  # 5 minutes
LOCATION_STALE_THRESHOLD="${LOCATION_STALE_THRESHOLD:-900}"  # 15 minutes
LOCATION_CONFIG_FILE="${LOCATION_CONFIG_FILE:-$HOME/.config/clima/wifi-locations.conf}"
LOCATION_DB_TIMEOUT="${LOCATION_DB_TIMEOUT:-5000}"  # 5 second busy timeout

# SQLite wrapper with busy timeout to prevent "database is locked" errors
_location_sqlite() {
    sqlite3 -cmd ".timeout $LOCATION_DB_TIMEOUT" "$LOCATION_DB" "$@" 2>/dev/null
}

# Ensure cache directory exists
_location_init() {
    local cache_dir="${LOCATION_DB:h}"
    [[ ! -d "$cache_dir" ]] && mkdir -p "$cache_dir"

    # Check if sqlite3 is available
    if ! command -v sqlite3 >/dev/null 2>&1; then
        return 1
    fi

    # Initialize database if it doesn't exist or is empty
    if [[ ! -f "$LOCATION_DB" ]] || ! _location_sqlite "SELECT name FROM sqlite_master WHERE type='table' AND name='current_location';" 2>/dev/null | grep -q current_location; then
        if [[ -f "$LOCATION_SCHEMA" ]]; then
            _location_sqlite < "$LOCATION_SCHEMA"
        else
            # Create complete schema inline if schema file not found
            _location_sqlite <<EOF
CREATE TABLE IF NOT EXISTS current_location (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  updated_at INTEGER NOT NULL,
  ssid TEXT, bssid TEXT, ip_address TEXT,
  network_type TEXT, network_interface TEXT,
  lat REAL NOT NULL, lon REAL NOT NULL,
  city TEXT, region TEXT, country_code TEXT,
  hostname TEXT NOT NULL,
  source TEXT NOT NULL, source_detail TEXT,
  confidence TEXT DEFAULT 'medium',
  vpn_active INTEGER DEFAULT 0,
  timezone TEXT, altitude REAL, accuracy_meters REAL,
  previous_lat REAL, previous_lon REAL,
  location_changed INTEGER DEFAULT 0
);
CREATE TABLE IF NOT EXISTS config (
  key TEXT PRIMARY KEY, value TEXT NOT NULL,
  updated_at INTEGER DEFAULT (strftime('%s', 'now'))
);
CREATE TABLE IF NOT EXISTS known_networks (
  ssid TEXT NOT NULL,
  bssid TEXT NOT NULL DEFAULT '',
  lat REAL NOT NULL,
  lon REAL NOT NULL,
  city TEXT,
  region TEXT,
  country_code TEXT,
  confidence REAL DEFAULT 1.0,
  location_variance_meters REAL DEFAULT 0,
  source TEXT DEFAULT 'learned',
  first_seen INTEGER NOT NULL,
  last_seen INTEGER NOT NULL,
  times_seen INTEGER DEFAULT 1,
  is_portable INTEGER DEFAULT 0,
  PRIMARY KEY (ssid, bssid)
);
CREATE TABLE IF NOT EXISTS location_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  timestamp INTEGER NOT NULL,
  ssid TEXT,
  bssid TEXT,
  ip_address TEXT,
  network_type TEXT,
  network_interface TEXT,
  lat REAL NOT NULL,
  lon REAL NOT NULL,
  city TEXT,
  region TEXT,
  country_code TEXT,
  hostname TEXT NOT NULL,
  source TEXT NOT NULL,
  source_detail TEXT,
  confidence TEXT,
  vpn_active INTEGER DEFAULT 0,
  timezone TEXT,
  altitude REAL,
  accuracy_meters REAL,
  duration_seconds INTEGER,
  departure_timestamp INTEGER
);
CREATE INDEX IF NOT EXISTS idx_known_networks_ssid ON known_networks(ssid);
CREATE INDEX IF NOT EXISTS idx_known_networks_last_seen ON known_networks(last_seen DESC);
CREATE INDEX IF NOT EXISTS idx_history_time ON location_history(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_history_ssid ON location_history(ssid);
CREATE INDEX IF NOT EXISTS idx_history_hostname ON location_history(hostname);
CREATE INDEX IF NOT EXISTS idx_history_location ON location_history(lat, lon);
INSERT OR IGNORE INTO config VALUES ('version', '1.0', strftime('%s', 'now'));
EOF
        fi

        # Import existing config file if it exists
        if [[ -f "$LOCATION_CONFIG_FILE" ]]; then
            _location_import_config
        fi
    fi

    return 0
}

# Get current location (fast read)
# Returns: lat lon source timestamp
location_get() {
    _location_init || return 1

    local result=$(_location_sqlite "SELECT lat, lon, source, updated_at FROM current_location WHERE id = 1;" 2>/dev/null)

    if [[ -n "$result" ]]; then
        echo "$result" | tr '|' ' '
        return 0
    else
        # No location yet
        return 1
    fi
}

# Get current location and export to environment
location_export() {
    _location_init || return 1

    local result=$(_location_sqlite "SELECT lat, lon, city, updated_at FROM current_location WHERE id = 1;" 2>/dev/null)

    if [[ -n "$result" ]]; then
        local lat lon city updated_at
        IFS='|' read -r lat lon city updated_at <<< "$result"

        export CLIMA_LAT="$lat"
        export CLIMA_LON="$lon"
        [[ -n "$city" ]] && export CLIMA_CITY="$city"
        return 0
    fi

    return 1
}

# Check if location is stale
location_is_stale() {
    _location_init || return 0  # Treat as stale if init fails

    local updated_at=$(_location_sqlite "SELECT updated_at FROM current_location WHERE id = 1;" 2>/dev/null)

    if [[ -z "$updated_at" ]]; then
        return 0  # No location = stale
    fi

    local now=$(date +%s)
    local age=$((now - updated_at))

    [[ $age -gt $LOCATION_UPDATE_INTERVAL ]]
}

# WiFi detection methods for macOS (each returns ssid|bssid|interface or empty)
_wifi_try_go_app() {
    command -v wifi-location >/dev/null 2>&1 || return 1
    local info=$(wifi-location 2>/dev/null)
    [[ -n "$info" ]] && echo "$info"
}

_wifi_try_wdutil() {
    command -v wdutil >/dev/null 2>&1 || return 1
    local info=$(wdutil info 2>/dev/null)
    [[ -z "$info" ]] && return 1
    local ssid=$(echo "$info" | awk '/SSID/ && !/BSSID/ {for(i=2;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/ $//' | head -1)
    local bssid=$(echo "$info" | awk '/BSSID/ {print $NF}' | head -1)
    [[ -n "$ssid" ]] && echo "${ssid}|${bssid}|"
}

_wifi_try_airport() {
    local info=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I 2>/dev/null)
    [[ -z "$info" || "$info" == *"<redacted>"* ]] && return 1
    local ssid=$(echo "$info" | awk -F': ' '/^ *SSID:/ {print $2}' | head -1)
    local bssid=$(echo "$info" | awk -F': ' '/^ *BSSID:/ {print $2}' | tr -d ' ')
    [[ -n "$ssid" ]] && echo "${ssid}|${bssid}|"
}

_wifi_try_networksetup() {
    local interface=$1
    [[ -z "$interface" ]] && return 1
    local info=$(networksetup -getairportnetwork "$interface" 2>/dev/null)
    [[ "$info" == *"not associated"* || "$info" == *"<redacted>"* ]] && return 1
    local ssid=$(echo "$info" | awk -F': ' '{print $2}')
    [[ -n "$ssid" ]] && echo "${ssid}||"
}

_wifi_try_applescript() {
    command -v get-wifi-applescript >/dev/null 2>&1 || return 1
    local info=$(get-wifi-applescript 2>/dev/null)
    [[ -z "$info" || "$info" == "missing value"* ]] && return 1
    local ssid bssid iface
    IFS='|' read -r ssid bssid iface <<< "$info"
    [[ -n "$ssid" && "$ssid" != "missing value" ]] && echo "${ssid}|${bssid}|${iface}"
}

_wifi_try_python() {
    command -v get-wifi-ssid >/dev/null 2>&1 || return 1
    local info=$(get-wifi-ssid 2>/dev/null)
    [[ -n "$info" ]] && echo "$info"
}

# Get WiFi SSID and BSSID (tries multiple methods in order of reliability)
_location_get_wifi() {
    local ssid="" bssid="" interface=""

    if [[ "$OSTYPE" == darwin* ]]; then
        interface=$(networksetup -listallhardwareports 2>/dev/null | awk '/Wi-Fi/{getline; print $2}')
        [[ -z "$interface" ]] && { echo "||"; return; }

        # Try each method until one succeeds
        local result=""
        for method in _wifi_try_go_app _wifi_try_wdutil _wifi_try_airport \
                      "_wifi_try_networksetup $interface" _wifi_try_applescript _wifi_try_python; do
            result=$(eval $method 2>/dev/null)
            if [[ -n "$result" ]]; then
                IFS='|' read -r ssid bssid iface <<< "$result"
                [[ -n "$iface" ]] && interface="$iface"
                break
            fi
        done

    elif [[ "$OSTYPE" == linux* ]]; then
        if command -v iwgetid >/dev/null 2>&1; then
            ssid=$(iwgetid -r 2>/dev/null)
            bssid=$(iwgetid -a 2>/dev/null | awk '{print $NF}')
            interface=$(iwgetid 2>/dev/null | cut -d' ' -f1)
        elif command -v nmcli >/dev/null 2>&1; then
            ssid=$(nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | cut -d: -f2)
            interface=$(nmcli -t -f device,type dev 2>/dev/null | grep ':wifi$' | cut -d: -f1 | head -1)
        fi
    fi

    echo "$ssid|$bssid|$interface"
}

# Get IP address
_location_get_ip() {
    local ip=""

    # Try common services
    ip=$(curl -s --max-time 2 https://api.ipify.org 2>/dev/null || \
         curl -s --max-time 2 https://icanhazip.com 2>/dev/null | tr -d '\n')

    echo "$ip"
}

# Look up known network in database
_location_lookup_network() {
    local ssid=$1
    local bssid=$2

    _location_init || return 1

    # Normalize empty bssid to empty string
    [[ -z "$bssid" ]] && bssid=""

    # Try exact match first (ssid + bssid)
    if [[ -n "$bssid" ]]; then
        local result=$(_location_sqlite "SELECT lat, lon, city, region, country_code, confidence, source FROM known_networks WHERE ssid = '$ssid' AND bssid = '$bssid' LIMIT 1;" 2>/dev/null)
        [[ -n "$result" ]] && echo "$result" && return 0
    fi

    # Try SSID-only match (empty bssid means any BSSID)
    local result=$(_location_sqlite "SELECT lat, lon, city, region, country_code, confidence, source FROM known_networks WHERE ssid = '$ssid' AND bssid = '' LIMIT 1;" 2>/dev/null)
    [[ -n "$result" ]] && echo "$result" && return 0

    return 1
}

# Update location (smart update with staleness check)
location_update() {
    # Skip if not stale
    location_is_stale || return 0

    # Run update in background to not block shell
    (location_force &)
}

# Try to get location from CoreLocation (with retries)
# Sets: lat, lon, city, region, country, source, source_detail, confidence
_location_try_corelocation() {
    command -v wifi-location >/dev/null 2>&1 || return 1

    local max_attempts=3
    local attempt=0

    while [[ $attempt -lt $max_attempts ]]; do
        ((attempt++))

        local info=$(wifi-location --location 2>/dev/null)
        [[ -z "$info" ]] && { sleep 1; continue; }

        local cl_ssid cl_bssid cl_interface cl_lat cl_lon cl_alt cl_acc
        IFS='|' read -r cl_ssid cl_bssid cl_interface cl_lat cl_lon cl_alt cl_acc <<< "$info"

        # Valid coordinates?
        [[ -z "$cl_lat" || -z "$cl_lon" || "$cl_lat" == "0.000000" ]] && { sleep 1; continue; }

        # Success - output location data
        local geocode=$(curl -s --max-time 2 \
            "https://nominatim.openstreetmap.org/reverse?format=json&lat=${cl_lat}&lon=${cl_lon}" 2>/dev/null)

        local city="" region="" country=""
        if [[ -n "$geocode" ]]; then
            city=$(echo "$geocode" | jq -r '.address.city // .address.town // .address.village // empty' 2>/dev/null)
            region=$(echo "$geocode" | jq -r '.address.state // empty' 2>/dev/null)
            country=$(echo "$geocode" | jq -r '.address.country_code // empty' 2>/dev/null | tr '[:lower:]' '[:upper:]')
        fi

        echo "${cl_lat}|${cl_lon}|${city}|${region}|${country}|corelocation|corelocation:wifi_positioning:attempt_${attempt}|high"
        return 0
    done

    return 1
}

# Try to get location from IP geolocation
# Sets: lat, lon, city, region, country, source, source_detail, confidence
_location_try_ip_geolocation() {
    local ip=$1
    [[ -z "$ip" ]] && return 1

    local result=$(curl -s --max-time 3 "http://ip-api.com/json/$ip?fields=lat,lon,city,regionName,countryCode,status" 2>/dev/null)
    echo "$result" | jq -e '.status == "success"' >/dev/null 2>&1 || return 1

    local lat=$(echo "$result" | jq -r .lat)
    local lon=$(echo "$result" | jq -r .lon)
    local city=$(echo "$result" | jq -r .city)
    local region=$(echo "$result" | jq -r .regionName)
    local country=$(echo "$result" | jq -r .countryCode)

    echo "${lat}|${lon}|${city}|${region}|${country}|ip|ip:api.com|medium"
    return 0
}

# Calculate Haversine distance between two points (returns miles)
_location_haversine_distance() {
    local lat1=$1 lon1=$2 lat2=$3 lon2=$4

    awk -v lat1="$lat1" -v lon1="$lon1" -v lat2="$lat2" -v lon2="$lon2" 'BEGIN {
        pi = 3.14159265358979323846
        lat1_rad = lat1 * pi / 180
        lat2_rad = lat2 * pi / 180
        dlat = (lat2 - lat1) * pi / 180
        dlon = (lon2 - lon1) * pi / 180
        a = sin(dlat/2) * sin(dlat/2) + cos(lat1_rad) * cos(lat2_rad) * sin(dlon/2) * sin(dlon/2)
        c = 2 * atan2(sqrt(a), sqrt(1-a))
        printf "%.0f", 3959 * c
    }'
}

# Apply home radius override if within range
# Input: lat|lon|city|region|country|source|source_detail|confidence
# Only applies to IP-based locations
_location_apply_home_override() {
    local location_data=$1
    local lat lon city region country source source_detail confidence
    IFS='|' read -r lat lon city region country source source_detail confidence <<< "$location_data"

    # Only override IP-based locations
    [[ "$source" != "ip" ]] && { echo "$location_data"; return 0; }

    local home_lat="${CLIMA_HOME_LAT:-}"
    local home_lon="${CLIMA_HOME_LON:-}"
    local home_city="${CLIMA_HOME_CITY:-}"
    local home_radius="${CLIMA_HOME_RADIUS:-100}"

    [[ -z "$home_lat" || -z "$home_lon" ]] && { echo "$location_data"; return 0; }

    local distance=$(_location_haversine_distance "$lat" "$lon" "$home_lat" "$home_lon")

    if [[ $distance -le $home_radius ]]; then
        [[ -n "$home_city" ]] && city="$home_city"
        echo "${home_lat}|${home_lon}|${city}|${region}|${country}|home_radius|ip:within_${distance}mi_of_home|medium"
    else
        echo "$location_data"
    fi
}

# Persist location to database
_location_persist() {
    local now=$1 hostname=$2 ssid=$3 bssid=$4 ip=$5 network_type=$6 interface=$7
    local lat=$8 lon=$9 city=${10} region=${11} country=${12}
    local source=${13} source_detail=${14} confidence=${15}

    # Escape single quotes for SQL
    ssid="${ssid//\'/\'\'}"
    city="${city//\'/\'\'}"
    region="${region//\'/\'\'}"

    _location_sqlite <<EOF
INSERT OR REPLACE INTO current_location (
  id, updated_at, ssid, bssid, ip_address, network_type, network_interface,
  lat, lon, city, region, country_code,
  hostname, source, source_detail, confidence
) VALUES (
  1, $now, '$ssid', '$bssid', '$ip', '$network_type', '$interface',
  $lat, $lon, '$city', '$region', '$country',
  '$hostname', '$source', '$source_detail', '$confidence'
);

INSERT INTO location_history (
  timestamp, ssid, bssid, ip_address, network_type, network_interface,
  lat, lon, city, region, country_code,
  hostname, source, source_detail, confidence
) VALUES (
  $now, '$ssid', '$bssid', '$ip', '$network_type', '$interface',
  $lat, $lon, '$city', '$region', '$country',
  '$hostname', '$source', '$source_detail', '$confidence'
);
EOF
}

# Export location to environment and tmux
_location_export_env() {
    local lat=$1 lon=$2 city=$3 location_changed=$4

    export CLIMA_LAT="$lat"
    export CLIMA_LON="$lon"
    [[ -n "$city" ]] && export CLIMA_CITY="$city"

    # Update tmux environment if running inside tmux
    if [[ -n "$TMUX" ]]; then
        tmux setenv -g CLIMA_LAT "$lat" 2>/dev/null
        tmux setenv -g CLIMA_LON "$lon" 2>/dev/null
        [[ -n "$city" ]] && tmux setenv -g CLIMA_CITY "$city" 2>/dev/null
        [[ $location_changed -eq 1 ]] && tmux set-option -g @clima_last_update_time 0 2>/dev/null
    fi
}

# Force immediate location update
location_force() {
    _location_init || return 1

    local now=$(date +%s)
    local hostname=$(hostname -s 2>/dev/null || hostname)

    # Get network info
    local wifi_info=$(_location_get_wifi)
    local ssid bssid interface
    IFS='|' read -r ssid bssid interface <<< "$wifi_info"
    [[ -z "$bssid" ]] && bssid=""

    local ip=$(_location_get_ip)
    local network_type="unknown"
    [[ -n "$ssid" ]] && network_type="wifi"
    [[ -z "$ssid" && -n "$ip" ]] && network_type="ethernet"

    # Try location sources in order of accuracy
    local location_data=""
    local lat lon city region country source source_detail confidence

    # 1. Try known WiFi network (instant, from database)
    if [[ -n "$ssid" ]]; then
        local network_info=$(_location_lookup_network "$ssid" "$bssid")
        if [[ -n "$network_info" ]]; then
            IFS='|' read -r lat lon city region country confidence source <<< "$network_info"
            location_data="${lat}|${lon}|${city}|${region}|${country}|${source}|wifi:${source}|${confidence}"
        fi
    fi

    # 2. Try CoreLocation (high accuracy, may take time)
    [[ -z "$location_data" && -n "$ssid" ]] && location_data=$(_location_try_corelocation)

    # 3. Try IP geolocation (lower accuracy, fast)
    [[ -z "$location_data" && -n "$ip" ]] && location_data=$(_location_try_ip_geolocation "$ip")

    # No location available
    [[ -z "$location_data" ]] && return 1

    # Apply home radius override
    location_data=$(_location_apply_home_override "$location_data")

    # Parse final location
    IFS='|' read -r lat lon city region country source source_detail confidence <<< "$location_data"

    # Check if location changed
    local prev_city=$(_location_sqlite "SELECT city FROM current_location WHERE id = 1;" 2>/dev/null)
    local location_changed=0
    [[ "$city" != "$prev_city" ]] && location_changed=1

    # Persist and export
    _location_persist "$now" "$hostname" "$ssid" "$bssid" "$ip" "$network_type" "$interface" \
        "$lat" "$lon" "$city" "$region" "$country" "$source" "$source_detail" "$confidence"

    _location_export_env "$lat" "$lon" "$city" "$location_changed"

    return 0
}

# Import wifi-locations.conf into database
_location_import_config() {
    [[ ! -f "$LOCATION_CONFIG_FILE" ]] && return 1

    _location_init

    local now=$(date +%s)

    while IFS=',' read -r ssid lat lon; do
        # Skip comments and empty lines
        [[ -z "$ssid" || "$ssid" =~ ^[[:space:]]*# ]] && continue

        # Trim whitespace
        ssid="${ssid#"${ssid%%[![:space:]]*}"}"
        ssid="${ssid%"${ssid##*[![:space:]]}"}"
        lat="${lat#"${lat%%[![:space:]]*}"}"
        lat="${lat%"${lat##*[![:space:]]}"}"
        lon="${lon#"${lon%%[![:space:]]*}"}"
        lon="${lon%"${lon##*[![:space:]]}"}"

        # Escape single quotes
        ssid="${ssid//\'/\'\'}"

        # Insert into known_networks (bssid empty string means any BSSID)
        _location_sqlite <<EOF
INSERT OR REPLACE INTO known_networks (
  ssid, bssid, lat, lon, confidence, source, first_seen, last_seen, times_seen
) VALUES (
  '$ssid', '', $lat, $lon, 1.0, 'config', $now, $now, 1
);
EOF
    done < "$LOCATION_CONFIG_FILE"

    return 0
}

# Initialize on module load and export current location
_location_init
location_export >/dev/null 2>&1 || true
