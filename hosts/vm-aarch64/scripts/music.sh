# eww-music: the dashboard's music section (configs/eww), a line of JSON
# whenever a player's track or state changes: {status, artist, title, cover}.
# The player is whichever playerctl finds, Spotify's web app in Chrome among
# them. GTK draws only local images, so the cover is fetched once per track
# into ~/.cache/eww; a line with an empty status hides the section.

cache=${XDG_CACHE_HOME:-$HOME/.cache}/eww
mkdir -p "$cache"

playerctl --follow metadata --format $'{{status}}\t{{artist}}\t{{title}}\t{{mpris:artUrl}}' 2>/dev/null |
	while IFS=$'\t' read -r status artist title url; do
		cover=''
		case $url in
		file://*) cover=${url#file://} ;;
		http://* | https://*)
			cover=$cache/cover-$(printf %s "$url" | md5sum | cut -c1-16)
			[[ -s $cover ]] || curl -fsSL --max-time 10 "$url" -o "$cover" || cover=''
			;;
		esac
		jq -cn --arg status "$status" --arg artist "$artist" --arg title "$title" \
			--arg cover "$cover" '{$status, $artist, $title, $cover}'
	done
