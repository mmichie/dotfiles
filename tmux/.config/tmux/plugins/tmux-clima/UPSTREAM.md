# Upstream Source

This plugin was originally cloned from:
- Repository: https://github.com/vascomfnunes/tmux-clima.git
- Commit: 9052e5c475ba0815bef2367fb473324f3c4e6d84
- Date: 2024-10-05

## Customizations

- Changed geolocation API from ifconfig.co to ip-api.com for better accuracy
- Modified display to show city name only (removed country code)
- Added Haversine distance calculation for proximity detection
- Added home location override with configurable radius
- Made home location configurable via environment variables (CLIMA_HOME_LAT, CLIMA_HOME_LON, CLIMA_HOME_RADIUS)

## Updating

To manually merge upstream updates:
1. Check for changes at https://github.com/vascomfnunes/tmux-clima
2. Review and manually apply relevant changes to scripts/clima.sh
3. Preserve customizations listed above
