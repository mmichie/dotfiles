# slstatus-system: CPU, memory and disk use for dwm's bar, as slstatus prints
# them every second at the start of its grey block (slstatus/config.h):
# "CPU  3%  MEM 46%  DSK 70%" in status2d's colour codes (dwm/status2d.diff),
# the words in the first colour given and each figure in it too, or in the
# second past its warning limit and in the third past its critical one. CPU
# is averaged over the last few seconds, so that a spike as a build starts
# does not flash it; the average and the counters it is taken from carry
# over between runs in $XDG_RUNTIME_DIR.
#
# Usage: slstatus-system NORMAL WARNING CRITICAL, each a colour as #rrggbb

normal=$1 warning=$2 critical=$3
state=${XDG_RUNTIME_DIR:-/tmp}/slstatus-system

# CPU: the share of the time since the last run not spent idle, from the
# first line of /proc/stat, kept in an average that holds 70% of the last
# one, so a second at full load reads 30% and five in a row 83%. In
# hundredths of a percent, for the shell's integers. The first run, with no
# state yet, takes the share since boot.
read -r _ user nice system idle iowait irq softirq steal _ </proc/stat
total=$((user + nice + system + idle + iowait + irq + softirq + steal))
idle=$((idle + iowait))
lasttotal=0 lastidle=0 avg=-1
if [[ -r $state ]]; then
	read -r lasttotal lastidle avg <"$state"
fi
busy=0
if ((total > lasttotal)); then
	busy=$((10000 * (total - lasttotal - (idle - lastidle)) / (total - lasttotal)))
fi
if ((avg < 0)); then
	avg=$busy
else
	avg=$(((7 * avg + 3 * busy) / 10))
fi
printf '%s %s %s\n' "$total" "$idle" "$avg" >"$state.new"
mv -f "$state.new" "$state"
cpu=$(((avg + 50) / 100))

# memory: the share a new program could not have without swapping, MemTotal
# less the kernel's MemAvailable
while read -r key value _; do
	case $key in
	MemTotal:) memtotal=$value ;;
	MemAvailable:)
		memavailable=$value
		break
		;;
	esac
done </proc/meminfo
mem=$(((100 * (memtotal - memavailable) + memtotal / 2) / memtotal))

# disk: the root filesystem's use, as df prints it
disk=$(df --output=pcent / | tail -n 1)
disk=${disk//[!0-9]/}

# a figure's colour: the figure, then its warning and critical limits
colour() {
	if (($1 >= $3)); then
		printf %s "$critical"
	elif (($1 >= $2)); then
		printf %s "$warning"
	else
		printf %s "$normal"
	fi
}

printf '^c%s^CPU ^c%s^%2d%%  ^c%s^MEM ^c%s^%2d%%  ^c%s^DSK ^c%s^%2d%%\n' \
	"$normal" "$(colour "$cpu" 80 95)" "$cpu" \
	"$normal" "$(colour "$mem" 80 90)" "$mem" \
	"$normal" "$(colour "$disk" 85 95)" "$disk"
