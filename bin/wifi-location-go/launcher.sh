#!/bin/bash
# Wrapper for wifi-location that launches it properly via macOS LaunchServices
# This is required for Location Services authorization on macOS Sequoia

OUTPUT_FILE="/tmp/wifi-location-$$.txt"
trap 'rm -f "$OUTPUT_FILE"' EXIT

# --latlon mode: stdout is "lat|lon" and empty stdout + non-zero exit
# signals "no fix" to plx weather --location-cmd.
latlon_mode=0
if [[ "$*" == *"--latlon"* ]]; then
    latlon_mode=1
fi

# Fast-fail when the app bundle is missing. Without this, `open` fails but
# we still spin in the polling loop below for the full timeout (35s in
# location modes), which blocks tmux's `plx weather` invocation and makes
# the city flicker off whenever plx's 15-min cache expires.
APP_BUNDLE="$HOME/Applications/wifi-location.app"
if [[ ! -d "$APP_BUNDLE" ]]; then
    if [[ "$latlon_mode" == 0 ]]; then
        echo "||"
    fi
    exit 1
fi

# Launch app bundle via open (required for Location Services auth)
env OUTPUT_FILE="$OUTPUT_FILE" open "$APP_BUNDLE" --args "$@"

# Wait for output file (max 3 seconds for fast mode, 35 seconds for location modes)
max_wait=30
if [[ "$*" == *"--location"* || "$*" == *"--latlon"* ]]; then
    max_wait=350 # 35 seconds for location mode (CoreLocation needs up to 30s)
fi

for _ in $(seq 1 "$max_wait"); do
    if [ -f "$OUTPUT_FILE" ]; then
        contents=$(cat "$OUTPUT_FILE")
        # In --latlon mode, empty output means CoreLocation didn't get a fix —
        # signal that to the caller with a non-zero exit and no stdout.
        if [[ "$latlon_mode" == 1 && -z "$contents" ]]; then
            exit 1
        fi
        printf '%s' "$contents"
        exit 0
    fi
    sleep 0.1
done

# Timeout. In --latlon mode, leave stdout empty; otherwise emit the legacy
# sentinel so scripts that parse the WiFi-info format see a recognizable shape.
if [[ "$latlon_mode" == 0 ]]; then
    echo "||"
fi
exit 1
