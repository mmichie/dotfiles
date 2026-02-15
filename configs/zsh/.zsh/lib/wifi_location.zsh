#!/usr/bin/env zsh

# WiFi-based location detection for tmux-clima
# This module uses the location_service to track network-aware location
# and automatically updates CLIMA_LAT/CLIMA_LON environment variables

# Precmd hook to update location periodically
_location_precmd_hook() {
    # Skip if disabled
    [[ -n "$DISABLE_WIFI_LOCATION" ]] && return

    # Update location (only if stale, runs in background)
    location_update
}

# Add to precmd hooks
autoload -Uz add-zsh-hook
add-zsh-hook precmd _location_precmd_hook

# Initialize location on module load
if [[ -z "$DISABLE_WIFI_LOCATION" ]]; then
    # Force initial update in background
    (location_force &)
fi
