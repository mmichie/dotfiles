# eww-github USER [WEEKS]: the dashboard's GitHub section (configs/eww): the
# last WEEKS weeks (26) of USER's public contribution calendar, the one
# GitHub draws on a profile page, so no token: {weeks, total}, each week the
# activity levels 0 to 4 of its seven days, -1 for those still to come.

user=$1
weeks=${2:-26}
if ! html=$(curl -fsSL --max-time 20 "https://github.com/users/$user/contributions"); then
	echo '{}'
	exit 0
fi
total=$(tr -s ' \n\t' ' ' <<<"$html" | grep -oE '[0-9,]+ contributions? in the last year' | head -1 |
	sed -E 's/ contributions? / /' || true)

# Each day's cell names its weekday (0 is Sunday) and week in its id.
grep -oE 'id="contribution-day-component-[0-6]-[0-9]+"[^>]*data-level="[0-4]"' <<<"$html" |
	sed -E 's/.*-([0-6])-([0-9]+)".*data-level="([0-4])"/\2 \1 \3/' |
	awk -v n="$weeks" -v total="$total" '
		{ level[$1, $2] = $3; if ($1 > last) last = $1 }
		END {
			printf "{\"total\":\"%s\",\"weeks\":[", total
			for (w = last - n + 1; w <= last; w++) {
				printf "%s[", (w > last - n + 1 ? "," : "")
				for (d = 0; d < 7; d++)
					printf "%s%s", (d ? "," : ""), ((w, d) in level ? level[w, d] : -1)
				printf "]"
			}
			print "]}"
		}'
