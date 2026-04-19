# WiFi-based Location Configuration for plx weather

This directory contains configuration for WiFi-based automatic location detection for the `plx weather` tmux status segment.

## How It Works

The `wifi_location.zsh` module (loaded in your zsh configuration) automatically:
1. Detects your current WiFi network SSID
2. Looks up the SSID in your `wifi-locations.conf` file
3. Sets `PLX_WEATHER_LAT` and `PLX_WEATHER_LON` environment variables if a match is found
4. `plx weather` uses these variables to show weather for your current location

## Setup

1. Copy the example config to create your own:
   ```bash
   cp ~/.config/clima/wifi-locations.conf.example ~/.config/clima/wifi-locations.conf
   ```

2. Edit `wifi-locations.conf` with your WiFi networks and locations:
   ```bash
   # Format: SSID,latitude,longitude
   MyHomeWiFi,37.7749,-122.4194
   OfficeWiFi,40.7128,-74.0060
   ```

3. Find your coordinates at: https://www.latlong.net/

4. Restart your shell or source your zsh config:
   ```bash
   source ~/.zshrc
   ```

## Configuration File Format

- **Format**: `SSID,latitude,longitude`
- **Comments**: Lines starting with `#` are ignored
- **Empty lines**: Ignored
- **SSID matching**: Case-sensitive, must match exactly
- **Coordinates**: Decimal degrees (e.g., 37.7749, -122.4194)

## Example

```conf
# Home network in San Francisco
HomeNetwork,37.7749,-122.4194

# Office in New York
OfficeWiFi,40.7128,-74.0060

# Parents' house
ParentsWiFi,34.0522,-118.2437
```

## Testing

Check if WiFi location detection is working:

```bash
# Check current WiFi SSID
get_wifi_ssid

# Check if location variables are set
echo "Latitude: $PLX_WEATHER_LAT"
echo "Longitude: $PLX_WEATHER_LON"

# Force refresh (restart shell or reload)
source ~/.zshrc
```

## Disabling WiFi Location

If you want to temporarily disable WiFi-based location detection:

```bash
export DISABLE_WIFI_LOCATION=1
```

Add this to your `~/.zshrc.local` to make it permanent.

## Troubleshooting

**Location not updating:**
- Check that your config file exists at `~/.config/clima/wifi-locations.conf`
- Verify the SSID matches exactly (case-sensitive)
- Make sure the file has correct format (no extra spaces, proper commas)
- Restart your shell to reload the configuration

**WiFi SSID not detected:**
- On macOS: Check that you have WiFi enabled
- On Linux: Ensure `iwgetid` or `nmcli` is installed
- Test with: `get_wifi_ssid` command

**Weather showing wrong location:**
- Verify `PLX_WEATHER_LAT` and `PLX_WEATHER_LON` are set: `echo $PLX_WEATHER_LAT $PLX_WEATHER_LON`
- Confirm tmux picked up the updated environment (`tmux show-environment -g | grep PLX_WEATHER`)
- Reload tmux config with `prefix + r` or restart the tmux server
