/* See LICENSE file for copyright and license details. */

/*
 * dwm for the vm-aarch64 guest: upstream's config.def.h (dwm 6.8) with the
 * changes marked below. The nix package copies this file over config.def.h
 * after applying the patches beside it, so when a dwm bump changes
 * config.def.h, carry the change over by hand.
 *
 * The colours, COL_BAR and the rest, come from palette.h, which
 * configuration.nix renders from hosts/vm-aarch64/palette.nix: the tmux
 * theme's for the bar, chadwm's for the tags (chadwmbar.diff), chevron's
 * for the chips (chips.diff). The bar is drawn in the look of tmux's status
 * line, its blocks joined by tmux's arrows (powerline.diff).
 */

/* appearance */
static const unsigned int borderpx  = 2;        /* border pixel of windows */
static const unsigned int gappx     = 10;       /* gap between and around tiled windows (gaps.diff) */
static const unsigned int snap      = 32;       /* snap pixel */
static const int showbar            = 1;        /* 0 means no bar */
static const int topbar             = 1;        /* 0 means bottom bar */
/* the bar's look (barstyle.diff) */
static const int vertpadbar         = 8;        /* height beyond the font's: 31px with JetBrains Mono at 15px */
static const int statusvpad         = 4;        /* the bar's blocks stop this short of its top and bottom */
static const int ulinepad           = 5;        /* the selected tab's underline (tab.diff): inset from the tab's sides */
static const int ulinestroke        = 2;        /* and its thickness, and the focused window's in the bar (barlist.diff) */
/* the bar after chadwm's (chadwmbar.diff); its colours are below */
static const int centretitle        = 0;        /* the title: 0 after the layout symbol, 1 centred on the screen (centeredwindowname.diff) */
static const int barlist            = 1;        /* 1: every window in the bar (barlist.diff); 0: the focused one's title alone */
#define ICONSIZE    16  /* window icons beside the title (winicon.diff) */
#define ICONSPACING 8   /* and the gap between icon and title */
/* monocle tabs (tab.diff): never, in monocle with more than one window
 * (showtab_auto), or always. Off, since the bar lists the windows */
enum showtab_modes { showtab_never, showtab_auto, showtab_always };
static const int showtab            = showtab_never;
static const int toptab             = 1;        /* tabs under the bar, not at the screen's foot */
static const int tabmaxw            = 400;      /* a tab's widest */
/* the system tray (systray.diff), at the bar's right end */
static const int showsystray        = 1;
static const unsigned int systraypinning = 0;   /* 0: the tray follows the selected monitor; n: pinned to monitor n */
static const int systraypinningfailfirst = 1;   /* pinned to a monitor that isn't there: 1 the first, 0 the last */
static const unsigned int systrayspacing = 8;   /* between icons, and at either end */
static const int systrayiconsize    = 18;       /* an icon's height */
/* st's font: JetBrains Mono SemiBold at 15px, drawn as on the Mac (fontconfig
 * in configuration.nix) */
static const char *fonts[]          = { "JetBrainsMono Nerd Font:size=11.25:weight=semibold" };
static const char dmenufont[]       = "JetBrainsMono Nerd Font:size=11.25:weight=semibold";
#include "palette.h"
/* a tag with windows is drawn in its own colour (by tag, chadwm's onedark;
 * chadwmbar.diff), and the selected one black on it between arrows, as tmux
 * draws its current window (powerline.diff) */
static const char *tagcolours[]     = { COL_BLUE, COL_RED, COL_ORANGE, COL_GREEN, COL_PINK, COL_YELLOW };
static const char *colors[][3]      = {
	/*                  fg            bg          border */
	[SchemeNorm]    = { COL_TEXT,     COL_BAR,    COL_BLOCK },
	[SchemeSel]     = { COL_ONACCENT, COL_ACCENT, COL_ACCENT },
	/* the focused window's title (titlescheme.diff); stock dwm uses SchemeSel */
	[SchemeTitle]   = { COL_BRIGHT,   COL_BAR,    COL_BLOCK },
	/* the selected tab in monocle (tab.diff) */
	[SchemeTagSel]  = { COL_BRIGHT,   COL_BAR,    COL_ACCENT },
	/* empty tags, dimmed (barstyle.diff) */
	[SchemeVacant]  = { COL_BLOCK,    COL_BAR,    COL_BLOCK },
	/* the layout symbol, black on white where tmux has the session's name
	 * (powerline.diff) */
	[SchemeLayout]  = { COL_ONACCENT, COL_BRIGHT, COL_BLOCK },
	/* a chip's text (chips.diff), as the status blocks' values, and tmux's
	 * grey step after the layout symbol (powerline.diff) */
	[SchemeChip]    = { COL_BRIGHT,   COL_BLOCK,  COL_BLOCK },
	/* another window's directory in the bar's window list (barlist.diff),
	 * plain grey, as tmux's other windows are */
	[SchemeChipDim] = { COL_TEXT,     COL_BAR,    COL_BLOCK },
};

/* chips (chips.diff): what a terminal publishes for the bar, drawn in place
 * of its title like the status blocks, each kind's icon on its colour and
 * then the text, joined by arrows as chevron's prompt is (powerline.diff).
 * dwm-chips (dwm/chips.sh) publishes the directory and the git branch and
 * status in chevron's colours, and an agent's state in the tmux marks' */
static const ChipKind chipkinds[] = {
	/* kind       icon                  colour      icon's colour */
	{ "dir",      "\xef\x81\xbb",       COL_DIR,     COL_WHITE },    /* nf-fa-folder */
	{ "branch",   "\xee\x82\xa0",       COL_BRANCH,  COL_WHITE },    /* the powerline branch */
	{ "waiting",  "\xf3\xb0\x9a\xa9",   COL_WAITING, COL_ONACCENT }, /* nf-md-robot: waiting on you */
	{ "working",  "\xf3\xb0\x9a\xa9",   COL_WORKING, COL_BRIGHT },
	{ "done",     "\xf3\xb0\x9a\xa9",   COL_DONE,    COL_ONACCENT }, /* finished its turn */
};

/* tagging: the tags, the window rules and DESKTOPKEYS (the per-tag keys, used
 * in keys[] below) are generated into desktops.h from lib/desktops.nix, the
 * desktops and app rules shared with AeroSpace on the Mac */
#include "desktops.h"

/* layout(s) */
static const float mfact     = 0.55; /* factor of master area size [0.05..0.95] */
static const int nmaster     = 1;    /* number of clients in master area */
/* 0: a terminal's size hints would round it down to whole character cells,
 * leaving its gaps uneven; st fills the slack with its background instead */
static const int resizehints = 0;    /* 1 means respect size hints in tiled resizals */
static const int lockfullscreen = 1; /* 1 will force focus on the fullscreen window */
static const int refreshrate = 120;  /* refresh rate (per second) for client move/resize */

static const Layout layouts[] = {
	/* symbol     arrange function */
	{ "[]=",      tile },    /* first entry is default */
	{ "><>",      NULL },    /* no layout function means floating behavior */
	{ "[M]",      monocle },
};

/* key definitions */
/* Super rather than Alt: UTM passes the Mac's Command key through as Super,
 * so the key next to Space is the modifier */
#define MODKEY Mod4Mask
#define TAGKEYS(KEY,TAG) \
	{ MODKEY,                       KEY,      view,           {.ui = 1 << TAG} }, \
	{ MODKEY|ControlMask,           KEY,      toggleview,     {.ui = 1 << TAG} }, \
	{ MODKEY|ShiftMask,             KEY,      tag,            {.ui = 1 << TAG} }, \
	{ MODKEY|ControlMask|ShiftMask, KEY,      toggletag,      {.ui = 1 << TAG} },

/* helper for spawning shell commands in the pre dwm-5.0 fashion */
#define SHCMD(cmd) { .v = (const char*[]){ "/bin/sh", "-c", cmd, NULL } }

/* Cmd+C and Cmd+V copy and paste, as on the Mac. Command reaches the guest as
 * Super, which no X application reads as copy or paste, so dwm takes the two
 * chords and sends the focused window its own: Ctrl+Shift+C/V to the
 * terminals (st, WezTerm, Ghostty, and st in tabbed, by window class),
 * where Ctrl+C is the interrupt, and Ctrl+C/V to everything else.
 * --clearmodifiers lifts the held Super while it types, so the window sees
 * only that chord. */
#define CLIPKEY(k) SHCMD("case \"$(xdotool getactivewindow getwindowclassname)\" in " \
	"st-256color|org.wezfurlong.wezterm|com.mitchellh.ghostty|tabbed) " \
	"xdotool key --clearmodifiers ctrl+shift+" k " ;; " \
	"*) xdotool key --clearmodifiers ctrl+" k " ;; esac")

/* spawn() for those two, once the C or V is up again. Until then X keeps the
 * keyboard grabbed for dwm, which fired on the press, and the key down, so a
 * chord xdotool typed meanwhile reached dwm instead of the window: a hand
 * holds a key longer than xdotool takes to start. The grab reports every key
 * event to dwm; modifiers are skipped, since Cmd can come up before the key. */
static void
spawnreleased(const Arg *arg)
{
	XEvent ev;

	do
		XMaskEvent(dpy, KeyReleaseMask, &ev);
	while (IsModifierKey(XLookupKeysym(&ev.xkey, 0)));
	spawn(arg);
}

/* commands */
static char dmenumon[2] = "0"; /* component of dmenucmd, manipulated in spawn() */
static char dmenuheight[4];    /* component of dmenucmd: the bar's height, written in setup() (barstyle.diff) */
static const char *dmenucmd[] = { "dmenu_run", "-m", dmenumon, "-h", dmenuheight, "-fn", dmenufont, "-nb", COL_BAR, "-nf", COL_BRIGHT, "-sb", COL_ACCENT, "-sf", COL_ONACCENT, NULL };
/* st as Ghostty starts on the Mac (configs/ghostty/config): in tmux, attached
 * to a detached session or a new one, or a plain shell once every session
 * already has a window (bin/tmux-attach-or-new). sh expands $HOME. */
#define TMUXSTART "\"$HOME/bin/tmux-attach-or-new\""
static const char *termcmd[]  = { "/bin/sh", "-c", "exec st -e " TMUXSTART, NULL };
/* rofi's app launcher (configs/rofi/config.rasi); Ctrl+Tab switches to its
 * other modes, commands and windows */
static const char *roficmd[]  = { "rofi", "-show", "drun", NULL };
static const char *windowcmd[] = { "rofi", "-show", "window", NULL };
/* st in tabbed, which closes with its last tab (tabbed/config.h); each tab
 * starts as termcmd does */
static const char *tabbedcmd[] = { "/bin/sh", "-c", "exec tabbed -c -r 2 st -w '' -e " TMUXSTART, NULL };
/* notifications (dunst, configs/dunst/dunstrc): dismiss the newest, dismiss
 * them all, bring back the last one dismissed */
static const char *dunstclose[]    = { "dunstctl", "close", NULL };
static const char *dunstcloseall[] = { "dunstctl", "close-all", NULL };
static const char *dunsthistory[]  = { "dunstctl", "history-pop", NULL };
/* the dashboard (configs/eww): the system, the time, the load, GitHub, the
 * music, the volume; eww starts its daemon on the first open. The calendar
 * is eww's too. */
static const char *ewwcmd[] = { "eww", "open", "--toggle", "dashboard", NULL };
static const char *calendarcmd[] = { "eww", "open", "--toggle", "calendar", NULL };
/* the menus, in rofi (configs/rofi): power and screenshots are scripts
 * (hosts/vm-aarch64/scripts), the clipboard's history is clipmenu's, the
 * emoji and the calculator are plugins; all but power copy what you pick */
static const char *powercmd[] = { "rofi-power", NULL };
static const char *shotcmd[]  = { "rofi-screenshot", NULL };
static const char *clipcmd[]  = { "/bin/sh", "-c", "CM_LAUNCHER=rofi exec clipmenu -p clipboard", NULL };
static const char *emojicmd[] = { "rofi", "-modi", "emoji", "-show", "emoji", "-emoji-mode", "copy", NULL };
static const char *calccmd[]  = { "rofi", "-modi", "calc", "-show", "calc", "-no-show-match", "-no-sort",
	"-no-history", "-calc-command", "printf %s '{result}' | xclip -selection clipboard", NULL };

/* the status blocks slstatus names (statusclick.diff; slstatus/config.h):
 * each command runs with sh, which gets the block's left and right edges,
 * the screen's right edge, the bar's bottom and the mouse button (1 a click,
 * 4 and 5 a scroll) as $1 to $5. DROPDOWN opens an eww window (configs/eww)
 * with its right edge under the block's, 10px below the bar, or closes it;
 * --pos= keeps eww from taking the negative offset for an option. */
#define DROPDOWN(win) "eww open --toggle " win " --anchor 'top right' --pos=\"-$(($3 - $2))x$(($4 + 10))\""
#define ONCLICK(cmd)  "[ \"$5\" = 1 ] && " cmd
static const StatusAction statusactions[] = {
	/* block    command */
	{ "music",  ONCLICK(DROPDOWN("music")) },
	{ "volume", "case $5 in 1) " DROPDOWN("volume") " ;; "
		"4) wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+ ;; 5) wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- ;; esac" },
	{ "cal",    ONCLICK(DROPDOWN("calendar")) },
	{ "clock",  ONCLICK(DROPDOWN("calendar")) },
	{ "power",  ONCLICK("rofi-power") },
};

static const Key keys[] = {
	/* modifier                     key        function        argument */
	{ MODKEY,                       XK_p,      spawn,          {.v = dmenucmd } },
	{ MODKEY|ShiftMask,             XK_Return, spawn,          {.v = termcmd } },
	{ MODKEY,                       XK_r,      spawn,          {.v = roficmd } },
	{ MODKEY,                       XK_a,      spawn,          {.v = ewwcmd } },
	{ MODKEY|ShiftMask,             XK_a,      spawn,          {.v = calendarcmd } },
	{ MODKEY|ShiftMask,             XK_e,      spawn,          {.v = powercmd } },
	{ MODKEY|ShiftMask,             XK_s,      spawn,          {.v = shotcmd } },
	{ MODKEY|ShiftMask,             XK_v,      spawn,          {.v = clipcmd } },
	{ MODKEY,                       XK_e,      spawn,          {.v = emojicmd } },
	{ MODKEY,                       XK_equal,  spawn,          {.v = calccmd } },
	{ MODKEY|ShiftMask,             XK_t,      spawn,          {.v = tabbedcmd } },
	{ MODKEY,                       XK_n,      spawn,          {.v = dunstclose } },
	{ MODKEY|ShiftMask,             XK_n,      spawn,          {.v = dunstcloseall } },
	{ MODKEY|ControlMask,           XK_n,      spawn,          {.v = dunsthistory } },
	{ MODKEY,                       XK_c,      spawnreleased,  CLIPKEY("c") },
	{ MODKEY,                       XK_v,      spawnreleased,  CLIPKEY("v") },
	{ MODKEY,                       XK_b,      togglebar,      {0} },
	{ MODKEY,                       XK_j,      focusstack,     {.i = +1 } },
	{ MODKEY,                       XK_k,      focusstack,     {.i = -1 } },
	{ MODKEY,                       XK_i,      incnmaster,     {.i = +1 } },
	{ MODKEY,                       XK_d,      incnmaster,     {.i = -1 } },
	{ MODKEY,                       XK_h,      setmfact,       {.f = -0.05} },
	{ MODKEY,                       XK_l,      setmfact,       {.f = +0.05} },
	{ MODKEY,                       XK_Return, zoom,           {0} },
	{ MODKEY,                       XK_Tab,    view,           {0} },
	{ MODKEY|ShiftMask,             XK_c,      killclient,     {0} },
	{ MODKEY,                       XK_t,      setlayout,      {.v = &layouts[0]} },
	{ MODKEY,                       XK_f,      setlayout,      {.v = &layouts[1]} },
	{ MODKEY,                       XK_m,      setlayout,      {.v = &layouts[2]} },
	{ MODKEY,                       XK_space,  setlayout,      {0} },
	{ MODKEY|ShiftMask,             XK_space,  togglefloating, {0} },
	{ MODKEY,                       XK_0,      view,           {.ui = ~0 } },
	{ MODKEY|ShiftMask,             XK_0,      tag,            {.ui = ~0 } },
	{ MODKEY,                       XK_comma,  focusmon,       {.i = -1 } },
	{ MODKEY,                       XK_period, focusmon,       {.i = +1 } },
	{ MODKEY|ShiftMask,             XK_comma,  tagmon,         {.i = -1 } },
	{ MODKEY|ShiftMask,             XK_period, tagmon,         {.i = +1 } },
	DESKTOPKEYS
	{ MODKEY|ShiftMask,             XK_q,      quit,           {0} },
	/* restart in place, keeping the windows (restartsig.diff) */
	{ MODKEY|ControlMask|ShiftMask, XK_q,      quit,           {1} },
};

/* button definitions */
/* click can be ClkTagBar, ClkLtSymbol, ClkStatusText, ClkWinTitle, ClkClientWin, or ClkRootWin */
static const Button buttons[] = {
	/* click                event mask      button          function        argument */
	{ ClkLtSymbol,          0,              Button1,        setlayout,      {0} },
	{ ClkLtSymbol,          0,              Button3,        setlayout,      {.v = &layouts[2]} },
	/* a window in the bar's window list (barlist.diff), or of a group of
	 * an app's windows the one focused longest ago (appgroups.diff) */
	{ ClkWinTitle,          0,              Button1,        focuswin,       {0} },
	{ ClkWinTitle,          0,              Button2,        zoom,           {0} },
	{ ClkStatusText,        0,              Button2,        spawn,          {.v = termcmd } },
	/* a status block's command (statusclick.diff), on a click or a scroll */
	{ ClkStatusText,        0,              Button1,        statusclick,    {0} },
	{ ClkStatusText,        0,              Button4,        statusclick,    {0} },
	{ ClkStatusText,        0,              Button5,        statusclick,    {0} },
	{ ClkClientWin,         MODKEY,         Button1,        movemouse,      {0} },
	{ ClkClientWin,         MODKEY,         Button2,        togglefloating, {0} },
	{ ClkClientWin,         MODKEY,         Button3,        resizemouse,    {0} },
	{ ClkTabBar,            0,              Button1,        focuswin,       {0} },
	{ ClkTagBar,            0,              Button1,        view,           {0} },
	{ ClkTagBar,            0,              Button3,        toggleview,     {0} },
	{ ClkTagBar,            MODKEY,         Button1,        tag,            {0} },
	{ ClkTagBar,            MODKEY,         Button3,        toggletag,      {0} },
	/* the desktop, which shows in the gaps and on an empty desktop: menus,
	 * as Enlightenment opens them there. A click that misses a window by a
	 * few pixels lands here, so the left button has the mildest, the window
	 * list; the middle one the power menu, the right one the launcher. */
	{ ClkRootWin,           0,              Button1,        spawn,          {.v = windowcmd } },
	{ ClkRootWin,           0,              Button2,        spawn,          {.v = powercmd } },
	{ ClkRootWin,           0,              Button3,        spawn,          {.v = roficmd } },
};
