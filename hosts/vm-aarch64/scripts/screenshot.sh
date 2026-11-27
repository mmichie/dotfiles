# rofi-screenshot: the screenshot menu (Mod+Shift+S in dwm/config.h), a row
# of icons (configs/rofi/menu.rasi): the screen, the focused window, an area
# you drag (Escape cancels), or the screen after 5 s. Each lands in
# ~/Pictures/Screenshots and on the clipboard, and a notification shows it.

screen=$'\xf3\xb0\x8d\xb9' # md-monitor
window=$'\xf3\xb0\x96\xaf' # md-window_maximize
area=$'\xf3\xb0\x92\x89'   # md-selection
timer=$'\xf3\xb0\x94\x9b'  # md-timer_outline

choice=$(printf '%s\n' "$screen" "$window" "$area" "$timer" |
	rofi -dmenu -config ~/.config/rofi/menu.rasi -p screenshot \
		-mesg "to ~/Pictures/Screenshots and the clipboard") || exit 0

dir=$HOME/Pictures/Screenshots
mkdir -p "$dir"
file=$dir/$(date +%Y-%m-%d_%H-%M-%S).png
sleep 0.3 # rofi's window has to be gone from the screen first
case $choice in
"$screen") maim "$file" ;;
"$window") maim -i "$(xdotool getactivewindow)" "$file" ;;
"$area") maim -s "$file" || exit 0 ;;
"$timer")
	sleep 5
	maim "$file"
	;;
*) exit 0 ;;
esac
xclip -selection clipboard -t image/png -i "$file"
notify-send -i "$file" "Screenshot" "${file/#$HOME/\~}, and on the clipboard"
