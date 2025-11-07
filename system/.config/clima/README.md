# WiFi-based Location Configuration for tmux-clima

This directory contains configuration for WiFi-based automatic location detection for the tmux-clima weather plugin.

## How It Works

The `wifi_location.zsh` module (loaded in your zsh configuration) automatically:
1. Detects your current WiFi network SSID
2. Looks up the SSID in your `wifi-locations.conf` file
3. Sets `CLIMA_LAT` and `CLIMA_LON` environment variables if a match is found
4. tmux-clima uses these variables to show weather for your current location

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
echo "Latitude: $CLIMA_LAT"
echo "Longitude: $CLIMA_LON"

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
- Verify `CLIMA_LAT` and `CLIMA_LON` are set: `echo $CLIMA_LAT $CLIMA_LON`
- Check that clima is reading the variables (priority order in clima README)
- Wait for the clima TTL to expire (default: 15 minutes) or restart tmux
