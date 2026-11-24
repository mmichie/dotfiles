/* See LICENSE file for copyright and license details. */

/*
 * dwm for the vm-aarch64 guest: upstream's config.def.h (dwm 6.8) with the
 * changes marked below. The nix package copies this file over config.def.h
 * after applying the patches beside it, so when a dwm bump changes
 * config.def.h, carry the change over by hand.
 *
 * The colours are the xterm-256 values of the tmux theme in
 * configs/tmux/tmux.conf, so dwm's bar and the tmux status line inside st
 * read as one theme: a colour234 bar, colour245 text, a colour39 accent.
 */

/* appearance */
static const unsigned int borderpx  = 2;        /* border pixel of windows */
static const unsigned int gappx     = 10;       /* gap between and around tiled windows (gaps.diff) */
static const unsigned int snap      = 32;       /* snap pixel */
static const int showbar            = 1;        /* 0 means no bar */
static const int topbar             = 1;        /* 0 means bottom bar */
static const char *fonts[]          = { "Hack Nerd Font:size=11" }; /* st's font */
static const char dmenufont[]       = "Hack Nerd Font:size=11";
static const char col_bar[]         = "#1c1c1c"; /* colour234 */
static const char col_text[]        = "#8a8a8a"; /* colour245 */
static const char col_title[]       = "#e4e4e4"; /* colour254 */
static const char col_accent[]      = "#00afff"; /* colour39 */
static const char col_onaccent[]    = "#000000"; /* colour16 */
static const char col_border[]      = "#444444"; /* colour238 */
static const char *colors[][3]      = {
	/*                fg            bg          border     */
	[SchemeNorm]  = { col_text,     col_bar,    col_border },
	[SchemeSel]   = { col_onaccent, col_accent, col_accent },
	/* the focused window's title (titlescheme.diff); stock dwm uses SchemeSel */
	[SchemeTitle] = { col_title,    col_bar,    col_border },
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
 * terminals (st, WezTerm, Ghostty, by window class), where Ctrl+C is the
 * interrupt, and Ctrl+C/V to everything else. --clearmodifiers lifts the held
 * Super while it types, so the window sees only that chord. */
#define CLIPKEY(k) SHCMD("case \"$(xdotool getactivewindow getwindowclassname)\" in " \
	"st-256color|org.wezfurlong.wezterm|com.mitchellh.ghostty) " \
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
static const char *dmenucmd[] = { "dmenu_run", "-m", dmenumon, "-fn", dmenufont, "-nb", col_bar, "-nf", col_title, "-sb", col_accent, "-sf", col_onaccent, NULL };
static const char *termcmd[]  = { "st", NULL };

static const Key keys[] = {
	/* modifier                     key        function        argument */
	{ MODKEY,                       XK_p,      spawn,          {.v = dmenucmd } },
	{ MODKEY|ShiftMask,             XK_Return, spawn,          {.v = termcmd } },
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
};

/* button definitions */
/* click can be ClkTagBar, ClkLtSymbol, ClkStatusText, ClkWinTitle, ClkClientWin, or ClkRootWin */
static const Button buttons[] = {
	/* click                event mask      button          function        argument */
	{ ClkLtSymbol,          0,              Button1,        setlayout,      {0} },
	{ ClkLtSymbol,          0,              Button3,        setlayout,      {.v = &layouts[2]} },
	{ ClkWinTitle,          0,              Button2,        zoom,           {0} },
	{ ClkStatusText,        0,              Button2,        spawn,          {.v = termcmd } },
	{ ClkClientWin,         MODKEY,         Button1,        movemouse,      {0} },
	{ ClkClientWin,         MODKEY,         Button2,        togglefloating, {0} },
	{ ClkClientWin,         MODKEY,         Button3,        resizemouse,    {0} },
	{ ClkTagBar,            0,              Button1,        view,           {0} },
	{ ClkTagBar,            0,              Button3,        toggleview,     {0} },
	{ ClkTagBar,            MODKEY,         Button1,        tag,            {0} },
	{ ClkTagBar,            MODKEY,         Button3,        toggletag,      {0} },
};
