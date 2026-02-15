#!/bin/bash

# Get battery status on macOS
battery_info=$(pmset -g batt | grep -Eo "\d+%" | cut -d% -f1)
charging_status=$(pmset -g batt | grep -o "charging\|discharging\|charged")

# Determine icon based on status
if [[ "$charging_status" == "charging" ]]; then
    icon="⚡"
elif [[ "$charging_status" == "charged" ]]; then
    icon="🔌"
else
    icon="🔋"
fi

# Output battery percentage with gray icon
echo "#[fg=colour245]${icon}#[default]${battery_info}%"
