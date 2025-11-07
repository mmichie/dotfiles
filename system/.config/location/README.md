# Shell Location Service

SQLite-based location service that provides automatic, network-aware geographic location tracking for shell, tmux, and location-aware tools like tmux-clima.

## Architecture

```
┌─────────────────────────────────────────────┐
│  Shell / tmux / Applications                │
│  Read: $CLIMA_LAT, $CLIMA_LON              │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│  Location Service (location_service.zsh)    │
│  - Detects WiFi/IP changes                  │
│  - Updates every 5 min (precmd hook)        │
│  - Exports CLIMA_LAT/CLIMA_LON              │
└──────────────────┬──────────────────────────┘
                   │
┌──────────────────▼──────────────────────────┐
│  SQLite Database (~/.cache/shell/location.db)│
│  - current_location (single row)            │
│  - location_history (append-only log)       │
│  - known_networks (SSID → coordinates)      │
│  - config (service settings)                │
└─────────────────────────────────────────────┘
```

## Features

### Current
- ✅ WiFi SSID/BSSID detection (macOS/Linux)
- ✅ IP-based location fallback
- ✅ Reverse geocoding (coordinates → city)
- ✅ SQLite persistence with history
- ✅ Auto-import from wifi-locations.conf
- ✅ Learning mode (auto-save WiFi networks)
- ✅ Multi-machine support (hostname tracking)
- ✅ Precmd hook (updates every command)
- ✅ Background updates (non-blocking)
- ✅ Comprehensive CLI

### Future
- ⏳ Background daemon (instant updates)
- ⏳ VPN detection
- ⏳ Timezone auto-adjustment
- ⏳ Battery-based travel mode
- ⏳ Network variance tracking
- ⏳ Altitude/accuracy tracking

## Quick Start

### First Time Setup

```bash
# 1. Service initializes automatically on first shell load
# 2. Check status
location status

# 3. If you have existing wifi-locations.conf, it's auto-imported
# Otherwise, learn networks as you go:

# Connect to WiFi → run a command → location updates via IP
# Then save this network:
location learn

# Repeat for each location you visit
```

### Typical Workflow

```bash
# Check current location
location status

# View known networks
location networks

# View history
location history 20

# Force update now
location force

# Learn current network
location learn
```

## CLI Reference

### Status and Information
```bash
location status              # Current location, age, staleness
location info                # Database info and statistics
location get                 # Raw output: lat lon source timestamp
```

### History and Networks
```bash
location history [N]         # Show last N locations (default: 10)
location networks            # Show all known WiFi networks
```

### Network Management
```bash
location learn               # Save current WiFi → location mapping
location import [file]       # Import from wifi-locations.conf
location export [file]       # Export to wifi-locations.conf
```

### Updates
```bash
location update              # Update if stale (smart update)
location force               # Force immediate update
```

## How It Works

### Location Detection Priority

1. **Known WiFi Network** - Exact SSID+BSSID match
2. **Known WiFi Network** - SSID-only match (any BSSID)
3. **IP Geolocation** - Falls back to ip-api.com
4. **Stale Data** - Uses last known if update fails

### Update Mechanism

- **Precmd Hook**: Runs after every command
- **Staleness Check**: Only updates if >5 min old
- **Background**: Runs in subshell, doesn't block prompt
- **Environment Export**: Sets `CLIMA_LAT`/`CLIMA_LON` automatically

### Data Tracked

#### Network Information
- SSID (WiFi network name)
- BSSID (WiFi MAC address - for multi-location SSIDs)
- IP address (public)
- Network type (wifi/ethernet/cellular/unknown)
- Network interface (en0, wlan0, etc)

#### Geographic Information
- Latitude/Longitude (decimal degrees)
- City, Region, Country (reverse geocoded)
- Source (wifi/ip/manual/home_radius)
- Source detail (wifi:config, wifi:learned, ip:api.com)
- Confidence (high/medium/low)

#### Machine Context
- Hostname (multi-machine tracking)
- Timestamp (when location was determined)
- Previous location (change tracking)

#### Future (placeholders in schema)
- VPN status
- Timezone
- Altitude
- Accuracy (meters)

## Configuration

### Environment Variables

```bash
# Database location
export LOCATION_DB="$HOME/.cache/shell/location.db"

# Schema file (for initialization)
export LOCATION_SCHEMA="$HOME/.config/location/schema.sql"

# Update intervals
export LOCATION_UPDATE_INTERVAL=300        # 5 minutes
export LOCATION_STALE_THRESHOLD=900        # 15 minutes

# Legacy config file (auto-imported)
export LOCATION_CONFIG_FILE="$HOME/.config/clima/wifi-locations.conf"

# Disable auto-updates
export DISABLE_WIFI_LOCATION=1
```

### Database Configuration

Stored in `config` table:

```sql
SELECT * FROM config;
-- version: 1.0
-- update_interval: 300
-- stale_threshold: 900
-- history_retention_days: 90
-- reverse_geocode: 1
-- auto_learn_networks: 1
```

## Database Schema

### Tables

**`current_location`** - Single row, always current
- Network: ssid, bssid, ip_address, network_type, network_interface
- Location: lat, lon, city, region, country_code
- Metadata: hostname, source, source_detail, confidence, updated_at
- Future: vpn_active, timezone, altitude, accuracy_meters

**`location_history`** - Append-only log
- Same fields as current_location
- Plus: duration_seconds, departure_timestamp

**`known_networks`** - WiFi SSID → Location mapping
- Network: ssid, bssid (NULL for any BSSID)
- Location: lat, lon, city, region, country_code
- Metadata: confidence, location_variance_meters, source
- Stats: first_seen, last_seen, times_seen, is_portable

**`config`** - Key-value configuration store

### Indexes

- `idx_history_time` - Fast recent history queries
- `idx_history_ssid` - Lookup by WiFi network
- `idx_history_hostname` - Per-machine queries
- `idx_history_location` - Geographic queries
- `idx_known_networks_ssid` - Fast network lookup
- `idx_known_networks_last_seen` - Recently used networks

## Examples

### Learning Networks

```bash
# At home
location force              # Gets IP-based location
location learn              # Saves "HomeWiFi" → lat/lon

# At office
location force
location learn              # Saves "OfficeWiFi" → lat/lon

# Now automatic: location updates whenever you connect
```

### Tracking Movement

```bash
# View your location history
location history 50

# Export for analysis
sqlite3 ~/.cache/shell/location.db \
  "SELECT datetime(timestamp, 'unixepoch', 'localtime') as time,
          ssid, city, lat, lon
   FROM location_history
   ORDER BY timestamp DESC;"
```

### Multi-Machine Setup

```bash
# View locations by machine
sqlite3 ~/.cache/shell/location.db \
  "SELECT hostname, city, COUNT(*) as visits
   FROM location_history
   GROUP BY hostname, city
   ORDER BY visits DESC;"
```

### Debugging

```bash
# Check what location service sees
location status

# Check environment variables
echo "Lat: $CLIMA_LAT, Lon: $CLIMA_LON, City: $CLIMA_CITY"

# Check precmd hook is active
typeset -f _location_precmd_hook

# Force update and watch
location force
location status

# View raw database
sqlite3 ~/.cache/shell/location.db "SELECT * FROM current_location;"
```

## Troubleshooting

### No location data

```bash
# Initialize
location force

# Check for errors
location status

# Verify database exists
ls -lh ~/.cache/shell/location.db
```

### Location not updating

```bash
# Check staleness
location status  # Look for "STALE" or age

# Check precmd hook
typeset -f _location_precmd_hook

# Force update
location force

# Check for errors in background job
jobs
```

### WiFi not detected

```bash
# Test WiFi detection (macOS)
networksetup -listallhardwareports
networksetup -getairportnetwork en0

# Test WiFi detection (Linux)
iwgetid -r
nmcli dev wifi list

# Manually add network
sqlite3 ~/.cache/shell/location.db
INSERT INTO known_networks (ssid, lat, lon, source, first_seen, last_seen)
VALUES ('MyWiFi', 37.7749, -122.4194, 'manual', strftime('%s','now'), strftime('%s','now'));
```

### Wrong location

```bash
# View known networks
location networks

# Update specific network
sqlite3 ~/.cache/shell/location.db
UPDATE known_networks
SET lat=37.7749, lon=-122.4194, city='San Francisco'
WHERE ssid='MyWiFi';

# Re-learn current network
location force && location learn
```

### Tmux not updating

```bash
# Tmux uses CLIMA_LAT/CLIMA_LON from environment
# These are set by precmd hook in each shell

# Force update in tmux pane
location force

# Check variables in tmux
tmux display-message "Lat: #{CLIMA_LAT}, Lon: #{CLIMA_LON}"

# Restart tmux-clima to use new location
tmux display-message "#{clima}"
```

## Performance

- **Database init**: ~5ms (one-time per shell)
- **Location read**: ~0.3ms (constant time)
- **Staleness check**: ~0.5ms (query + comparison)
- **Background update**: 1-3s (doesn't block shell)
- **Precmd overhead**: <1ms when fresh, ~0.5ms when stale check

For a 50ms prompt, location service adds <2% overhead.

## Privacy

### Data Stored Locally
- All data in `~/.cache/shell/location.db`
- No telemetry or external logging
- IP address cached locally (not sent anywhere except geolocation API)

### External API Calls
- **ip-api.com** - IP geolocation (no auth, rate limited)
- **ip-api.com** - Reverse geocoding (no auth, rate limited)
- Both requests include IP address and coordinates

### Disabling
```bash
export DISABLE_WIFI_LOCATION=1
```

## Migration from File-Based Config

Old config files are automatically imported:

```bash
# Auto-import on first run
# Or manual import
location import ~/.config/clima/wifi-locations.conf

# Export back to file format
location export ~/wifi-backup.conf

# Continue using both (file → DB on shell startup)
```

## Future Daemon Design

The architecture supports a future background daemon:

```
┌─────────────────────────────────────────┐
│  location-daemon (future)                │
│  - Monitors network changes via OS APIs │
│  - Updates SQLite immediately           │
│  - Signals precmd hook to reload        │
└─────────────────────────────────────────┘
         │
         ▼
    Same SQLite DB
         │
         ▼
┌─────────────────────────────────────────┐
│  Shell precmd (existing)                 │
│  - Detects daemon is running            │
│  - Just reads from DB (no update logic) │
│  - Exports CLIMA_LAT/CLIMA_LON           │
└─────────────────────────────────────────┘
```

No code changes needed in shells - daemon writes to same DB, shells just read faster.

## See Also

- `~/.config/clima/wifi-locations.conf.example` - Legacy config format
- `~/.config/location/schema.sql` - Full database schema
- `zsh/.zsh/lib/location_service.zsh` - Core service implementation
- `zsh/.zsh/lib/wifi_location.zsh` - Precmd hook integration
- `zsh/.zsh/functions/location_cli.zsh` - CLI commands
