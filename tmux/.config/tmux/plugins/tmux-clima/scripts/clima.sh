#!/usr/bin/env bash

CWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$CWD/tmux.sh"
source "$CWD/icons.sh"

# Weather data reference: http://openweathermap.org/weather-conditions

TTL=$((60 * $(get_tmux_option @clima_ttl 15)))
UNIT=$(get_tmux_option @clima_unit "metric")
SHOW_ICON=$(get_tmux_option @clima_show_icon 1)
SHOW_LOCATION=$(get_tmux_option @clima_show_location 1)
CLIMA_LOCATION=$(get_tmux_option @clima_location "")

calculate_distance() {
    # Simple distance calculation in miles using Haversine formula
    local lat1=$1
    local lon1=$2
    local lat2=$3
    local lon2=$4

    # Use awk for floating point math
    awk -v lat1="$lat1" -v lon1="$lon1" -v lat2="$lat2" -v lon2="$lon2" 'BEGIN {
        pi = 3.14159265358979323846
        lat1_rad = lat1 * pi / 180
        lat2_rad = lat2 * pi / 180
        dlat = (lat2 - lat1) * pi / 180
        dlon = (lon2 - lon1) * pi / 180
        a = sin(dlat/2) * sin(dlat/2) + cos(lat1_rad) * cos(lat2_rad) * sin(dlon/2) * sin(dlon/2)
        c = 2 * atan2(sqrt(a), sqrt(1-a))
        distance = 3959 * c
        printf "%.0f", distance
    }'
}

get_location_coordinates() {
    local loc_response=""
    local lat=""
    local lon=""

    # Home location from environment variables (optional)
    local home_lat="${CLIMA_HOME_LAT:-}"
    local home_lon="${CLIMA_HOME_LON:-}"
    local home_radius="${CLIMA_HOME_RADIUS:-100}"  # miles

    if [ -z "$1" ]; then
        # Get IP-based location
        loc_response=$(curl --silent http://ip-api.com/json)
        lat=$(echo "$loc_response" | jq -r .lat)
        lon=$(echo "$loc_response" | jq -r .lon)

        # If home location is configured, check if we're within radius
        if [ -n "$home_lat" ] && [ -n "$home_lon" ]; then
            distance=$(calculate_distance "$lat" "$lon" "$home_lat" "$home_lon")

            # If within home radius, use home location
            if [ "$distance" -le "$home_radius" ]; then
                lat="$home_lat"
                lon="$home_lon"
            fi
        fi
    else
        loc_response=$(curl --silent "http://api.openweathermap.org/geo/1.0/direct?q=$CLIMA_LOCATION&limit=1&appid=$OPEN_WEATHER_API_KEY")
        lat=$(echo "$loc_response" | jq -r '.[0].lat')
        lon=$(echo "$loc_response" | jq -r '.[0].lon')
    fi

    echo -n "$(jq -n --arg "lat" "$lat" \
        --arg "lon" "$lon" \
        '{lat: $lat, lon: $lon}')"
}

clima() {
    NOW=$(date +%s)
    LAST_UPDATE_TIME=$(get_tmux_option @clima_last_update_time)
    CLIMA_LAST_LOCATION=$(get_tmux_option @clima_last_location "")
    MOD=$((NOW - LAST_UPDATE_TIME))
    SYMBOL=$(symbol "$UNIT")
    if [ -z "$LAST_UPDATE_TIME" ] || [ "$MOD" -ge "$TTL" ] || [ "$CLIMA_LOCATION" != "$CLIMA_LAST_LOCATION" ]; then
        LOCATION=$(get_location_coordinates "$CLIMA_LOCATION")
        LAT=$(echo "$LOCATION" | jq -r .lat)
        LON=$(echo "$LOCATION" | jq -r .lon)
        WEATHER=$(curl --silent "http://api.openweathermap.org/data/2.5/weather?lat=$LAT&lon=$LON&APPID=$OPEN_WEATHER_API_KEY&units=$UNIT")
        if [ "$?" -eq 0 ]; then
            CATEGORY=$(echo "$WEATHER" | jq '.weather[0].id')
            TEMP="$(echo "$WEATHER" | jq .main.temp | cut -d . -f 1)$SYMBOL"
            ICON="$(icon "$CATEGORY")"
            CITY="$(echo "$WEATHER" | jq -r .name)"
            COUNTRY="$(echo "$WEATHER" | jq -r .sys.country)"
            DESCRIPTION="$(echo "$WEATHER" | jq -r '.weather[0].main')"
            FEELS_LIKE="Feels like: $(echo "$WEATHER" | jq .main.feels_like | cut -d . -f 1)$SYMBOL"
            WIND_SPEED="Wind speed: $(echo "$WEATHER" | jq .wind.speed) m/s"
            CLIMA=""

            if [ "$SHOW_LOCATION" == 1 ]; then
                CLIMA="$CLIMA$CITY "
            fi

            if [ "$SHOW_ICON" == 1 ]; then
                CLIMA="$CLIMA$ICON"
            fi

            CLIMA="$CLIMA$TEMP"
            CLIMA_DETAILS="${CITY}, ${COUNTRY}: ${ICON} ${TEMP}, ${DESCRIPTION}, ${FEELS_LIKE}, ${WIND_SPEED}"

            set_tmux_option "@clima_last_update_time" "$NOW"
            set_tmux_option "@clima_current_value" "$CLIMA"
            set_tmux_option "@clima_details_value" "$CLIMA_DETAILS"
            set_tmux_option "@clima_last_location" "$CLIMA_LOCATION"
        fi
    fi

    echo -n "$(get_tmux_option "@clima_current_value")"
}

clima
