# macOS WiFi Detection Setup

## The Problem

As of macOS 14.5+, Apple requires **Location Services** permission to access WiFi SSID information. This is an intentional privacy change that affects all command-line tools including:

- `networksetup -getairportnetwork` → Returns "You are not associated" or `<redacted>`
- `wdutil info` → Returns `<redacted>` for SSID/BSSID
- `airport` command → Deprecated and returns `<redacted>`
- `system_profiler` → Returns `<redacted>` for SSID

Full Disk Access is **not sufficient** - you specifically need Location Services permission.

## The Solution

The location service includes a Python helper script (`get-wifi-ssid`) that uses Apple's CoreWLAN framework with proper Location Services authorization.

### Setup Steps

#### 1. The script uses `uv` (already installed)

The script automatically manages its own dependencies using `uv`. No manual pip install needed!

#### 2. Grant Location Services Permission

Run the script directly in your terminal (not through Claude Code):

```bash
get-wifi-ssid
```

**First time:** macOS will show a dialog: "Python would like to access your location". Click **Allow** or **Allow While Using App**.

**If no dialog appears:**
```bash
# Open Location Services settings
open "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices"

# Find "Python" in the list and toggle it ON
```

#### 3. Verify It Works

```bash
# Should now show your actual SSID
get-wifi-ssid

# Output format: ssid|bssid|interface
# Example: MyHomeWiFi|a1:b2:c3:d4:e5:f6|en0
```

#### 4. Test Location Service

```bash
# Reload shell
source ~/.zshrc

# Force location update
location force

# Check status (should show WiFi SSID)
location status
```

## How It Works

The location service tries multiple methods in order:

1. **wdutil** (requires Full Disk Access)
2. **airport** command (deprecated)
3. **networksetup** (blocked by privacy in macOS 14.5+)
4. **Python CoreWLAN helper** with Location Services ← This one works!
5. **IP-based geolocation** (fallback)

## Troubleshooting

### "Location Services not authorized"

The script needs to be run from your actual terminal, not through automation tools or Claude Code. Run `get-wifi-ssid` directly in Terminal/iTerm/etc.

### Still showing `<redacted>`

1. Make sure you granted Location Services (not Full Disk Access)
2. Check System Settings → Privacy & Security → Location Services → Python is ON
3. Try restarting your terminal app after granting permission

### Python not found in Location Services

The first time you run `get-wifi-ssid`, macOS should auto-add Python to Location Services and prompt you. If it doesn't:

1. Try running: `get-wifi-ssid` again
2. The authorization prompt appears only once - if you denied it, you need to manually enable it in System Settings

### Script runs but returns empty

If the script runs without errors but returns `||`:
- You're not connected to WiFi
- Location Services is denied
- CoreWLAN can't access the interface

Check with: `ifconfig en0 | grep status`

### Want to test without WiFi detection?

The location service works fine without WiFi - it falls back to IP-based geolocation:

```bash
# Disable WiFi detection
export DISABLE_WIFI_LOCATION=1

# Or just use IP-based location
location force  # Uses your IP address to determine location
```

## Why IP-Based Fallback is Good Enough

For most use cases (including yours: 2 location changes/day, 5-10 min lag acceptable), IP-based geolocation works perfectly:

- Detects your city/region accurately
- No permissions needed
- Works everywhere (home, office, coffee shops)
- Updates automatically via precmd hook

WiFi detection is nice-to-have for:
- Exact location at multi-building campuses
- Faster detection (no network call)
- Works offline

## Technical Details

### uv Script Dependencies

The `get-wifi-ssid` script uses PEP 723 inline script metadata:

```python
#!/usr/bin/env -S uv run --quiet --script
# /// script
# dependencies = [
#     "pyobjc-framework-CoreWLAN",
#     "pyobjc-framework-CoreLocation",
# ]
# ///
```

This means:
- `uv` automatically creates an isolated environment
- Dependencies are cached for fast subsequent runs
- No system Python pollution
- Works on any machine with `uv` installed

### macOS Privacy Timeline

- **macOS 14.4 and earlier**: WiFi SSID accessible via command-line
- **macOS 14.5**: `wdutil info` started returning `<redacted>`
- **macOS 15.0**: `networksetup` requires Location Services
- **macOS 15.1+**: Even more restrictive, some APIs return empty regardless

### Alternative Approaches Considered

1. **Full Disk Access**: Doesn't help with WiFi SSID access
2. **sudo commands**: `sudo wdutil info` still returns `<redacted>`
3. **system_profiler**: Also returns `<redacted>` in recent versions
4. **Swift/Obj-C binary**: Would require compilation, same Location Services requirement
5. **Manual config file**: Works but requires manual updates

## References

- [Apple Developer Forums: macOS get SSID changes](https://developer.apple.com/forums/thread/732431)
- [Stack Overflow: CoreWLAN Location Services](https://stackoverflow.com/questions/73066192/how-to-enable-location-services-for-corewlan-pyobjc-wrapper-to-get-bssid)
- [Jamf Community: Collecting active SSID with macOS Sonoma 14.4+](https://community.jamf.com/t5/jamf-pro/collecting-active-ssid-with-macos-sonoma-14-4-and-later/m-p/311680)
