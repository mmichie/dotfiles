/* See LICENSE file for copyright and license details. */

/*
 * slstatus for the vm-aarch64 guest: the status text at the right of dwm's
 * bar. Upstream's config.def.h (slstatus 1.1) with its own args[]; the nix
 * package copies this file over config.def.h. The functions args[] can use
 * are listed in that config.def.h.
 *
 * In the desktop's colours (palette.h, which configuration.nix renders from
 * hosts/vm-aarch64/palette.nix) and the look of tmux's status line
 * (configs/tmux/tmux.conf), through status2d's codes (dwm/status2d.diff).
 * It is one grey block, as the weather and the time are in tmux's line:
 * the music and the volume, their icons in the accent since a click opens
 * their dropdowns, then CPU, memory and disk use, the date and the time,
 * parted by tmux's thin arrow. A figure turns amber past its warning limit
 * and red past its critical one (slstatus-system), and the block runs into
 * the power icon, black on white, as tmux's line ends in its host name.
 *
 * ^<#rrggbb^ sets the background through tmux's arrow, the new colour
 * pointing left over the old (dwm/powerline.diff), ^c#rrggbb^ sets the
 * text, ^d^ goes back to the bar's own colours, and ^f10^ skips 10px, the
 * gap before the system tray: as wide as the gaps between windows (gappx
 * in dwm/config.h). dwm draws the block a little short of the bar's top
 * and bottom (statusvpad, dwm/barstyle.diff).
 *
 * The figures carry the words chevron's banner uses for them (CPU, MEM,
 * DSK): their icons, a chip, a memory module and a disk, were hard to tell
 * apart in the bar. The icons come from one Nerd Font set, Material Design,
 * whose glyphs share a size (mixed sets overhang their cell unevenly).
 * Those and the thin arrow are spelled as UTF-8 bytes, since few editors
 * show private-use characters.
 */

/* interval between updates (in ms) */
const unsigned int interval = 1000;

/* text to show if no value can be retrieved */
static const char unknown_str[] = "n/a";

/* maximum output string length */
#define MAXLEN 2048

#include "palette.h"
#define GREY     "^<" COL_BLOCK "^" /* the block's start */
#define ICON(s)  "^c" COL_ACCENT "^" s "^c" COL_BRIGHT "^"
#define THIN     "\xee\x82\xb1" /* U+E0B1, tmux's thin arrow */
#define PART     "^c" COL_TEXT "^" THIN "^c" COL_BRIGHT "^" /* between the block's parts, each spaced */
#define CAP(s)   "^<" COL_BRIGHT "^^c" COL_ONACCENT "^ " s /* END spaces it */
#define BLOCK(n) "^a" n "^" /* a part dwm acts on when clicked, to ^a^: dwm/statusclick.diff */
#define END      " ^a^^d^^f10^"
#define MUSIC  "\xf3\xb0\x9d\x9a" /* U+F075A md-music */
#define VOLUME "\xf3\xb0\x95\xbe" /* U+F057E md-volume_high */
#define POWER  "\xf3\xb0\x90\xa5" /* U+F0425 md-power */

/* The playing track's title after the music icon, or ^f0^, which draws
 * nothing, when no player has one: run_command shows n/a for no output. A ^
 * in a title would read as a code. */
#define TRACK "t=$(playerctl metadata --format '{{trunc(title, 28)}}' 2>/dev/null | tr -d '^'); " \
	"if [ -n \"$t\" ]; then printf ' %s' \"$t\"; else printf '^f0^'; fi"
/* The volume, or muted. wpctl warns on stderr each time it runs (there is no
 * RTKit here), which slstatus would pass on to the session's output, the
 * journal, every second. */
#define LEVEL "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '{ if ($3 == \"[MUTED]\") printf \"muted\"; else printf \"%d%%\", $2 * 100 }'"
/* CPU, memory and disk use, from slstatus-system
 * (hosts/vm-aarch64/scripts/system.sh), which takes the figures' colours:
 * within their limits, past the warning one, past the critical one. Quoted,
 * or sh would read each # as the start of a comment. */
#define SYSTEM "slstatus-system '" COL_BRIGHT "' '" COL_URGENT "' '" COL_ALERT "'"

/* Named parts open a dropdown under them when clicked (statusactions in
 * dwm/config.h): the music and the volume theirs, where a scroll also sets
 * the volume, the date and the time the calendar, the power icon its menu.
 * Each takes in the spaces around it, so a click there counts. */
static const struct arg args[] = {
	/* function    format                                               argument */
	{ run_command, GREY BLOCK("music") " " ICON(MUSIC) "%s ^a^",        TRACK },
	{ run_command, PART BLOCK("volume") " " ICON(VOLUME) " %s ^a^",     LEVEL },
	{ run_command, PART " %s ",                                         SYSTEM },
	{ datetime,    PART BLOCK("cal") " %s ^a^",                         "%a %d %b" },
	{ datetime,    PART BLOCK("clock") " %s "
	               BLOCK("power") CAP(POWER) END,                       "%R" },
};
