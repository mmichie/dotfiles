# slstatus-follow: redraws dwm's status the moment the volume or the music
# changes, rather than at slstatus's next second. slstatus redraws at once on
# SIGUSR1, which interrupts its wait between updates; a signal that comes
# while it is drawing is lost, and the next second's update covers it. The
# X session starts this beside slstatus (configuration.nix).
#
# The volume through PulseAudio's events, which PipeWire serves: a change on
# a sink, or on the server, where the default sink is set. The music through
# playerctl: a new track, or playing or paused, from any player. Each source
# starts again a second after it ends, as when PipeWire restarts.

poke() {
	while read -r _; do
		pkill -USR1 -x -U "$UID" slstatus || true
	done
}

while :; do
	pactl subscribe 2>/dev/null | grep --line-buffered -E "'change' on (sink|server)" | poke || true
	sleep 1
done &

while :; do
	playerctl --all-players --follow metadata --format '{{status}} {{title}}' 2>/dev/null | poke || true
	sleep 1
done &

wait
