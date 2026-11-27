/* See LICENSE file for copyright and license details. */

/*
 * slstatus for the vm-aarch64 guest: the status text at the right of dwm's
 * bar. Upstream's config.def.h (slstatus 1.1) with its own args[]; the nix
 * package copies this file over config.def.h. The functions args[] can use
 * are listed in that config.def.h.
 *
 * Each value sits in blocks of the desktop's colours (palette.h, which
 * configuration.nix renders from hosts/vm-aarch64/palette.nix), through
 * status2d's codes (dwm/status2d.diff): its label or icon black on the
 * accent, then the value in colour254 on colour238, like the blocks of
 * tmux's status line. ^b#rrggbb^ sets the background,
 * ^c#rrggbb^ the text, ^d^ goes back to the bar's own colours, and ^f10^
 * skips 10px, the gap after each item: as wide as the gaps between windows
 * (gappx in dwm/config.h). dwm draws the blocks a little short of the bar's
 * top and bottom (statusvpad, dwm/barstyle.diff).
 *
 * The percentages carry the words chevron's banner uses for them (CPU, MEM,
 * DSK): their icons, a chip, a memory module and a disk, were hard to tell
 * apart in the bar. The date and time keep icons, both from one Nerd Font
 * set, Material Design, whose glyphs share a size (mixed sets overhang
 * their cell unevenly). They are spelled as UTF-8 bytes, since few editors
 * show private-use characters.
 */

/* interval between updates (in ms) */
const unsigned int interval = 1000;

/* text to show if no value can be retrieved */
static const char unknown_str[] = "n/a";

/* maximum output string length */
#define MAXLEN 2048

#include "palette.h"
#define LABEL(s) "^b" COL_ACCENT "^^c" COL_ONACCENT "^ " s " "
#define VALUE    "^b" COL_BLOCK "^^c" COL_BRIGHT "^ "
#define BLOCK(n) "^a" n "^" /* a block dwm acts on when clicked: dwm/statusclick.diff */
#define END      " ^a^^d^^f10^"
#define CAL    "\xf3\xb0\xb8\x97" /* U+F0E17 md-calendar_month */
#define CLOCK  "\xf3\xb0\x85\x90" /* U+F0150 md-clock_outline */
#define MUSIC  "\xf3\xb0\x9d\x9a" /* U+F075A md-music */
#define VOLUME "\xf3\xb0\x95\xbe" /* U+F057E md-volume_high */
#define POWER  "\xf3\xb0\x90\xa5" /* U+F0425 md-power */

/* The playing track's title in a value block, or ^d^, which draws nothing,
 * when no player has one: run_command shows n/a for no output. A ^ in a
 * title would read as a code. */
#define TRACK "t=$(playerctl metadata --format '{{trunc(title, 28)}}' 2>/dev/null | tr -d '^'); " \
	"if [ -n \"$t\" ]; then printf '%s%s' '" VALUE "' \"$t\"; else printf '^d^'; fi"
/* The volume, or muted. wpctl warns on stderr each time it runs (there is no
 * RTKit here), which slstatus would pass on to the session's output, the
 * journal, every second. */
#define LEVEL "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{ if ($3 == \"[MUTED]\") printf \"muted\"; else printf \"%d%%\", $2 * 100 }'"

/* Named blocks open a dropdown under them when clicked (statusactions in
 * dwm/config.h): the track and the volume theirs, where a scroll also sets
 * the volume, the date and the clock the calendar, the power icon its menu. */
static const struct arg args[] = {
	/* function    format                                         argument */
	{ cpu_perc,    LABEL("CPU") VALUE "%s%%" END,                 NULL },
	{ ram_perc,    LABEL("MEM") VALUE "%s%%" END,                 NULL },
	{ disk_perc,   LABEL("DSK") VALUE "%s%%" END,                 "/" },
	{ run_command, BLOCK("music") LABEL(MUSIC) "%s" END,          TRACK },
	{ run_command, BLOCK("volume") LABEL(VOLUME) VALUE "%s" END,  LEVEL },
	{ datetime,    BLOCK("cal") LABEL(CAL) VALUE "%s" END,        "%a %d %b" },
	{ datetime,    BLOCK("clock") LABEL(CLOCK) VALUE "%s" END
	               BLOCK("power") LABEL(POWER) END,               "%R" },
};
