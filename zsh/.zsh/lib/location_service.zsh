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

# Ensure cache directory exists
_location_init() {
    local cache_dir="${LOCATION_DB:h}"
    [[ ! -d "$cache_dir" ]] && mkdir -p "$cache_dir"

    # Initialize database if it doesn't exist or is empty
    if [[ ! -f "$LOCATION_DB" ]] || ! sqlite3 "$LOCATION_DB" "SELECT name FROM sqlite_master WHERE type='table' AND name='current_location';" 2>/dev/null | grep -q current_location; then
        if [[ -f "$LOCATION_SCHEMA" ]]; then
            sqlite3 "$LOCATION_DB" < "$LOCATION_SCHEMA"
        else
            # Create complete schema inline if schema file not found
            sqlite3 "$LOCATION_DB" <<EOF
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
    _location_init

    local result=$(sqlite3 "$LOCATION_DB" "SELECT lat, lon, source, updated_at FROM current_location WHERE id = 1;" 2>/dev/null)

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
    _location_init

    local result=$(sqlite3 "$LOCATION_DB" "SELECT lat, lon, city, updated_at FROM current_location WHERE id = 1;" 2>/dev/null)

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
    _location_init

    local updated_at=$(sqlite3 "$LOCATION_DB" "SELECT updated_at FROM current_location WHERE id = 1;" 2>/dev/null)

    if [[ -z "$updated_at" ]]; then
        return 0  # No location = stale
    fi

    local now=$(date +%s)
    local age=$((now - updated_at))

    [[ $age -gt $LOCATION_UPDATE_INTERVAL ]]
}

# Get WiFi SSID and BSSID
_location_get_wifi() {
    local ssid=""
    local bssid=""
    local interface=""

    if [[ "$OSTYPE" == darwin* ]]; then
        interface=$(networksetup -listallhardwareports 2>/dev/null | awk '/Wi-Fi/{getline; print $2}')
        if [[ -n "$interface" ]]; then
            # Try multiple methods for WiFi detection on macOS

            # Method 0: Try wifi-location Go app (properly signed, works on macOS Sequoia)
            if [[ -z "$ssid" ]] && command -v wifi-location >/dev/null 2>&1; then
                local go_info=$(wifi-location 2>/dev/null)
                if [[ -n "$go_info" ]]; then
                    local go_ssid go_bssid go_interface
                    IFS='|' read -r go_ssid go_bssid go_interface <<< "$go_info"
                    [[ -n "$go_ssid" ]] && ssid="$go_ssid"
                    [[ -n "$go_bssid" ]] && bssid="$go_bssid"
                    [[ -n "$go_interface" ]] && interface="$go_interface"
                fi
            fi

            # Method 1: Try wdutil (works on macOS 11+, requires Full Disk Access)
            if [[ -z "$ssid" ]] && command -v wdutil >/dev/null 2>&1; then
                local wdutil_info=$(wdutil info 2>/dev/null)
                ssid=$(echo "$wdutil_info" | awk '/SSID/ && !/BSSID/ {for(i=2;i<=NF;i++) printf "%s ", $i; print ""}' | sed 's/ $//' | head -1)
                bssid=$(echo "$wdutil_info" | awk '/BSSID/ {print $NF}' | head -1)
            fi

            # Method 2: Try airport command if exists
            if [[ -z "$ssid" ]]; then
                local airport_info=$(/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I 2>/dev/null)
                if [[ -n "$airport_info" ]] && [[ "$airport_info" != *"<redacted>"* ]]; then
                    ssid=$(echo "$airport_info" | awk -F': ' '/^ *SSID:/ {print $2}' | head -1)
                    bssid=$(echo "$airport_info" | awk -F': ' '/^ *BSSID:/ {print $2}' | tr -d ' ')
                fi
            fi

            # Method 3: Try networksetup (often blocked by privacy settings)
            if [[ -z "$ssid" ]]; then
                local ns_info=$(networksetup -getairportnetwork "$interface" 2>/dev/null)
                if [[ "$ns_info" != *"not associated"* ]] && [[ "$ns_info" != *"<redacted>"* ]]; then
                    ssid=$(echo "$ns_info" | awk -F': ' '{print $2}')
                fi
            fi

            # Method 4: Try AppleScript CoreWLAN (requires Location Services for osascript)
            if [[ -z "$ssid" ]] && command -v get-wifi-applescript >/dev/null 2>&1; then
                local as_info=$(get-wifi-applescript 2>/dev/null)
                if [[ -n "$as_info" ]] && [[ "$as_info" != "missing value"* ]]; then
                    local as_ssid as_bssid as_interface
                    IFS='|' read -r as_ssid as_bssid as_interface <<< "$as_info"
                    [[ -n "$as_ssid" && "$as_ssid" != "missing value" ]] && ssid="$as_ssid"
                    [[ -n "$as_bssid" && "$as_bssid" != "missing value" ]] && bssid="$as_bssid"
                    [[ -n "$as_interface" ]] && interface="$as_interface"
                fi
            fi

            # Method 5: Try Python CoreWLAN helper (requires Location Services permission)
            if [[ -z "$ssid" ]] && command -v get-wifi-ssid >/dev/null 2>&1; then
                local python_info=$(get-wifi-ssid 2>/dev/null)
                if [[ -n "$python_info" ]]; then
                    local py_ssid py_bssid py_interface
                    IFS='|' read -r py_ssid py_bssid py_interface <<< "$python_info"
                    [[ -n "$py_ssid" ]] && ssid="$py_ssid"
                    [[ -n "$py_bssid" ]] && bssid="$py_bssid"
                    [[ -n "$py_interface" ]] && interface="$py_interface"
                fi
            fi
        fi
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

# Reverse geocode coordinates to city/region/country
_location_reverse_geocode() {
    local lat=$1
    local lon=$2

    # Check if reverse geocoding is enabled
    local enabled=$(sqlite3 "$LOCATION_DB" "SELECT value FROM config WHERE key = 'reverse_geocode';" 2>/dev/null)
    [[ "$enabled" != "1" ]] && return 1

    # Use ip-api.com for reverse geocoding (free, no key needed)
    local result=$(curl -s --max-time 3 "http://ip-api.com/json/?lat=$lat&lon=$lon&fields=city,regionName,countryCode" 2>/dev/null)

    if [[ -n "$result" ]]; then
        local city=$(echo "$result" | jq -r .city 2>/dev/null)
        local region=$(echo "$result" | jq -r .regionName 2>/dev/null)
        local country=$(echo "$result" | jq -r .countryCode 2>/dev/null)

        echo "$city|$region|$country"
        return 0
    fi

    return 1
}

# Look up known network in database
_location_lookup_network() {
    local ssid=$1
    local bssid=$2

    _location_init

    # Normalize empty bssid to empty string
    [[ -z "$bssid" ]] && bssid=""

    # Try exact match first (ssid + bssid)
    if [[ -n "$bssid" ]]; then
        local result=$(sqlite3 "$LOCATION_DB" "SELECT lat, lon, city, region, country_code, confidence, source FROM known_networks WHERE ssid = '$ssid' AND bssid = '$bssid' LIMIT 1;" 2>/dev/null)
        [[ -n "$result" ]] && echo "$result" && return 0
    fi

    # Try SSID-only match (empty bssid means any BSSID)
    local result=$(sqlite3 "$LOCATION_DB" "SELECT lat, lon, city, region, country_code, confidence, source FROM known_networks WHERE ssid = '$ssid' AND bssid = '' LIMIT 1;" 2>/dev/null)
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

# Force immediate location update
location_force() {
    _location_init

    local now=$(date +%s)
    local hostname=$(hostname -s 2>/dev/null || hostname)

    # Get network info
    local wifi_info=$(_location_get_wifi)
    local ssid bssid interface
    IFS='|' read -r ssid bssid interface <<< "$wifi_info"

    # Normalize empty bssid to empty string for consistency
    [[ -z "$bssid" ]] && bssid=""

    local ip=$(_location_get_ip)
    local network_type="unknown"

    if [[ -n "$ssid" ]]; then
        network_type="wifi"
    elif [[ -n "$ip" ]]; then
        network_type="ethernet"
    fi

    # Try to get location
    local lat lon city region country source source_detail confidence

    # 1. Try known WiFi network (instant lookup from database)
    if [[ -n "$ssid" ]]; then
        local network_info=$(_location_lookup_network "$ssid" "$bssid")
        if [[ -n "$network_info" ]]; then
            IFS='|' read -r lat lon city region country confidence source <<< "$network_info"
            source_detail="wifi:${source}"
        fi
    fi

    # 2. Try CoreLocation for WiFi-based positioning (1-5 seconds, more accurate than IP)
    if [[ -z "$lat" ]] && [[ -n "$ssid" ]] && command -v wifi-location >/dev/null 2>&1; then
        local coreloc_info=$(wifi-location --location 2>/dev/null)
        if [[ -n "$coreloc_info" ]]; then
            local cl_ssid cl_bssid cl_interface cl_lat cl_lon cl_alt cl_acc
            IFS='|' read -r cl_ssid cl_bssid cl_interface cl_lat cl_lon cl_alt cl_acc <<< "$coreloc_info"

            # If we got coordinates from CoreLocation
            if [[ -n "$cl_lat" && -n "$cl_lon" && "$cl_lat" != "0.000000" ]]; then
                lat="$cl_lat"
                lon="$cl_lon"
                source="corelocation"
                source_detail="corelocation:wifi_positioning"
                confidence="high"

                # Reverse geocode to get city name
                local geocode_info=$(curl -s --max-time 2 \
                    "https://nominatim.openstreetmap.org/reverse?format=json&lat=${lat}&lon=${lon}" \
                    2>/dev/null)
                if [[ -n "$geocode_info" ]]; then
                    city=$(echo "$geocode_info" | jq -r '.address.city // .address.town // .address.village // empty' 2>/dev/null)
                    region=$(echo "$geocode_info" | jq -r '.address.state // empty' 2>/dev/null)
                    country=$(echo "$geocode_info" | jq -r '.address.country_code // empty' 2>/dev/null | tr '[:lower:]' '[:upper:]')
                fi
            fi
        fi
    fi

    # 3. Fall back to IP-based location (requires internet, less accurate)
    if [[ -z "$lat" ]] && [[ -n "$ip" ]]; then
        local ip_location=$(curl -s --max-time 3 "http://ip-api.com/json/$ip?fields=lat,lon,city,regionName,countryCode,status" 2>/dev/null)
        if echo "$ip_location" | jq -e '.status == "success"' >/dev/null 2>&1; then
            lat=$(echo "$ip_location" | jq -r .lat)
            lon=$(echo "$ip_location" | jq -r .lon)
            city=$(echo "$ip_location" | jq -r .city)
            region=$(echo "$ip_location" | jq -r .regionName)
            country=$(echo "$ip_location" | jq -r .countryCode)
            source="ip"
            source_detail="ip:api.com"
            confidence="medium"
        fi
    fi

    # 4. If still no location, can't update
    [[ -z "$lat" ]] && return 1

    # 5. Apply home radius override for low-confidence (IP-based) locations only
    # High-confidence sources (known wifi, corelocation) are never overridden
    local home_lat="${CLIMA_HOME_LAT:-}"
    local home_lon="${CLIMA_HOME_LON:-}"
    local home_radius="${CLIMA_HOME_RADIUS:-100}"

    if [[ "$source" == "ip" ]] && [[ -n "$home_lat" ]] && [[ -n "$home_lon" ]]; then
        # Calculate distance using Haversine formula
        local distance=$(awk -v lat1="$lat" -v lon1="$lon" -v lat2="$home_lat" -v lon2="$home_lon" 'BEGIN {
            pi = 3.14159265358979323846
            lat1_rad = lat1 * pi / 180
            lat2_rad = lat2 * pi / 180
            dlat = (lat2 - lat1) * pi / 180
            dlon = (lon2 - lon1) * pi / 180
            a = sin(dlat/2) * sin(dlat/2) + cos(lat1_rad) * cos(lat2_rad) * sin(dlon/2) * sin(dlon/2)
            c = 2 * atan2(sqrt(a), sqrt(1-a))
            distance = 3959 * c
            printf "%.0f", distance
        }')

        # If within home radius, use home coordinates instead of IP location
        if [[ $distance -le $home_radius ]]; then
            lat="$home_lat"
            lon="$home_lon"
            source="home_radius"
            source_detail="ip:within_${distance}mi_of_home"
            confidence="medium"
            # Keep city from reverse geocode or leave as-is
        fi
    fi

    # Escape single quotes in SQL values
    ssid="${ssid//\'/\'\'}"
    city="${city//\'/\'\'}"
    region="${region//\'/\'\'}"

    # Update current location
    sqlite3 "$LOCATION_DB" <<EOF
INSERT OR REPLACE INTO current_location (
  id, updated_at, ssid, bssid, ip_address, network_type, network_interface,
  lat, lon, city, region, country_code,
  hostname, source, source_detail, confidence
) VALUES (
  1, $now, '$ssid', '$bssid', '$ip', '$network_type', '$interface',
  $lat, $lon, '$city', '$region', '$country',
  '$hostname', '$source', '$source_detail', '$confidence'
);

-- Also log to history
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

    # Export to environment
    export CLIMA_LAT="$lat"
    export CLIMA_LON="$lon"
    [[ -n "$city" ]] && export CLIMA_CITY="$city"

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
        sqlite3 "$LOCATION_DB" <<EOF
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
