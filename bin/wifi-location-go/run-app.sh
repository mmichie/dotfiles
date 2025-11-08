#!/bin/bash
# Run the wifi-location app and capture output

# Create a temp file to capture output
TEMP_OUTPUT="/tmp/wifi-location-output.txt"

# Run the app in the background
open -W -a ./build/wifi-location.app

# Since macOS apps run in background, we need a different approach
# Let's just run the binary directly from the bundle
./build/wifi-location.app/Contents/MacOS/wifi-location
