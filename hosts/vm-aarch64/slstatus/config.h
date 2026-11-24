/* See LICENSE file for copyright and license details. */

/*
 * slstatus for the vm-aarch64 guest: the status text at the right of dwm's
 * bar. Upstream's config.def.h (slstatus 1.1) with its own args[]; the nix
 * package copies this file over config.def.h. The functions args[] can use
 * are listed in that config.def.h.
 *
 * Each icon takes the bar's accent, #00afff (col_accent in dwm/config.h),
 * through status2d's codes (dwm/status2d.diff): ^c#rrggbb^ sets the colour
 * and ^d^ goes back to the bar's grey text for the value.
 *
 * The icons are Nerd Font glyphs from one set, Material Design, because its
 * glyphs share a size; mixed sets overhang their cell unevenly. They are
 * spelled as UTF-8 bytes, since few editors show private-use characters.
 */

/* interval between updates (in ms) */
const unsigned int interval = 1000;

/* text to show if no value can be retrieved */
static const char unknown_str[] = "n/a";

/* maximum output string length */
#define MAXLEN 2048

#define ICON(glyph) "^c#00afff^" glyph "^d^ "
#define CPU   ICON("\xf3\xb0\xbb\xa0") /* U+F0EE0 md-cpu_64_bit */
#define RAM   ICON("\xf3\xb0\x8d\x9b") /* U+F035B md-memory */
#define DISK  ICON("\xf3\xb0\x8b\x8a") /* U+F02CA md-harddisk */
#define CAL   ICON("\xf3\xb0\xb8\x97") /* U+F0E17 md-calendar_month */
#define CLOCK ICON("\xf3\xb0\x85\x90") /* U+F0150 md-clock_outline */

static const struct arg args[] = {
	/* function  format               argument */
	{ cpu_perc,  " " CPU "%s%%",      NULL },
	{ ram_perc,  "    " RAM "%s%%",   NULL },
	{ disk_perc, "    " DISK "%s%%",  "/" },
	{ datetime,  "    " CAL "%s",     "%a %d %b" },
	{ datetime,  "    " CLOCK "%s ",  "%R" },
};
