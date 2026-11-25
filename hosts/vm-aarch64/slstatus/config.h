/* See LICENSE file for copyright and license details. */

/*
 * slstatus for the vm-aarch64 guest: the status text at the right of dwm's
 * bar. Upstream's config.def.h (slstatus 1.1) with its own args[]; the nix
 * package copies this file over config.def.h. The functions args[] can use
 * are listed in that config.def.h.
 *
 * Each value follows a label or icon in the bar's accent, #00afff
 * (col_accent in dwm/config.h), through status2d's codes
 * (dwm/status2d.diff): ^c#rrggbb^ sets the colour and ^d^ goes back to the
 * bar's grey text for the value.
 *
 * The percentages carry the words chevron's banner uses for them (CPU, MEM,
 * DSK): their icons, a chip, a memory module and a disk, were hard to tell
 * apart at the bar's 20px. The date and time keep icons, both from one Nerd
 * Font set, Material Design, whose glyphs share a size (mixed sets overhang
 * their cell unevenly). They are spelled as UTF-8 bytes, since few editors
 * show private-use characters.
 */

/* interval between updates (in ms) */
const unsigned int interval = 1000;

/* text to show if no value can be retrieved */
static const char unknown_str[] = "n/a";

/* maximum output string length */
#define MAXLEN 2048

#define ACCENT(s) "^c#00afff^" s "^d^ "
#define CAL   ACCENT("\xf3\xb0\xb8\x97") /* U+F0E17 md-calendar_month */
#define CLOCK ACCENT("\xf3\xb0\x85\x90") /* U+F0150 md-clock_outline */

static const struct arg args[] = {
	/* function  format                        argument */
	{ cpu_perc,  " " ACCENT("CPU") "%s%%",     NULL },
	{ ram_perc,  "    " ACCENT("MEM") "%s%%",  NULL },
	{ disk_perc, "    " ACCENT("DSK") "%s%%",  "/" },
	{ datetime,  "    " CAL "%s",              "%a %d %b" },
	{ datetime,  "    " CLOCK "%s ",           "%R" },
};
