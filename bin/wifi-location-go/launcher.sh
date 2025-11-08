#!/bin/bash
# Launcher that runs wifi-location with proper app bundle context

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
APP_PATH="$SCRIPT_DIR/build/wifi-location.app"

# Run the app using open and capture output
# Use -W to wait for completion, -n to open new instance, -g to not bring to foreground
open -W -g -n "$APP_PATH" 2>&1
