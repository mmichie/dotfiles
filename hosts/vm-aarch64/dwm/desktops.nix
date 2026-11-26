# desktops.h, which config.h includes: dwm's tags, its window rules and the
# keys for each tag, generated from the desktops shared with AeroSpace
# (lib/desktops.nix).
{ lib, writeText }:
let
  inherit (import ../../../lib/desktops.nix)
    desktops
    icons
    apps
    floating
    ;

  cstr = s: if s == null then "NULL" else ''"${lib.escape [ "\\" "\"" ] s}"'';

  # A desktop's label in the bar: its icon, as a C universal character name
  # (the compiler stores it as UTF-8), or else its name.
  label = d: if icons ? ${d} then ''"\U${lib.fixedWidthString 8 "0" icons.${d}}"'' else cstr d;

  # { class, instance, title, tags mask, isfloating, monitor }, as in dwm's Rule
  rule =
    x11: mask: float:
    "\t{ ${cstr (x11.class or null)}, ${cstr (x11.instance or null)}, NULL, ${mask}, ${if float then "1" else "0"}, -1 },";

  desktopRules = lib.concatLists (
    lib.imap0 (
      i: d:
      map (app: rule app.x11 "1 << ${toString i}" false) (lib.filter (app: app ? x11) (apps.${d} or [ ]))
    ) desktops
  );
  floatingRules = map (app: rule app.x11 "0" true) (lib.filter (app: app ? x11) floating);
in
writeText "desktops.h" ''
  /* Generated from lib/desktops.nix by hosts/vm-aarch64/dwm/desktops.nix. */

  static const char *tags[] = { ${lib.concatMapStringsSep ", " label desktops} };

  static const Rule rules[] = {
  	/* class, instance, title, tags mask, isfloating, monitor */
  ${lib.concatStringsSep "\n" (desktopRules ++ floatingRules)}
  };

  /* Mod+N shows desktop N, Mod+Shift+N moves the window there (TAGKEYS) */
  #define DESKTOPKEYS \
  ${lib.concatStringsSep " \\\n" (lib.imap0 (i: d: "\tTAGKEYS(XK_${d}, ${toString i})") desktops)}
''
