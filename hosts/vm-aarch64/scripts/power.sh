# rofi-power: the power menu (Mod+Shift+E in dwm/config.h), a row of icons
# (configs/rofi/menu.rasi) under the uptime: restart dwm in place, log out,
# reboot or power off. Logging out ends the X session, closing every window,
# and lightdm logs straight back in; it and the other two ask first.

restart=$'\xf3\xb0\x91\x93' # md-reload
logout=$'\xf3\xb0\x8d\x83'  # md-logout
reboot=$'\xf3\xb0\x9c\x89'  # md-restart
off=$'\xf3\xb0\x90\xa5'     # md-power

up=$(awk '{ s = int($1); d = int(s / 86400); h = int(s % 86400 / 3600)
	printf "up "; if (d) printf "%dd ", d; if (d || h) printf "%dh ", h
	printf "%dm", int(s % 3600 / 60) }' /proc/uptime)

# sure WHAT: yes or no, in the launcher's style
sure() {
	[[ $(printf 'no\nyes\n' | rofi -dmenu -p "$1?" -mesg "every window closes") == yes ]]
}

choice=$(printf '%s\n' "$restart" "$logout" "$reboot" "$off" |
	rofi -dmenu -config ~/.config/rofi/menu.rasi -p power -mesg "$up") || exit 0
case $choice in
"$restart") pkill -HUP -x dwm ;;
"$logout") if sure "log out"; then pkill -TERM -x dwm; fi ;;
"$reboot") if sure reboot; then systemctl reboot; fi ;;
"$off") if sure "power off"; then systemctl poweroff; fi ;;
esac
