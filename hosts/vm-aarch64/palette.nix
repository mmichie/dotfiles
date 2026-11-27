# The VM desktop's colours, in one place: every program that draws the
# desktop takes them from here. dwm (and dmenu, which dwm starts), slstatus
# and tabbed read them at build time from the C header `c` renders
# (configuration.nix). rofi, dunst and eww read their configs live from
# configs/, so `just palette` writes `rasi`, `scss` and `dunst` into files
# beside them, and the flake's palette check fails when those files and this
# one disagree.
#
# The bar's colours are the xterm-256 values of the tmux theme
# (configs/tmux/tmux.conf), so dwm's bar and the tmux status line in st read
# as one theme. The desktops take chadwm's onedark (dwm/chadwmbar.diff), and
# the chips chevron's prompt colours and the tmux marks' (dwm/chips.diff).
let
  colours = {
    bar = "#1c1c1c"; # colour234
    text = "#8a8a8a"; # colour245
    bright = "#e4e4e4"; # colour254
    block = "#444444"; # colour238
    accent = "#00afff"; # colour39
    onaccent = "#000000"; # colour16
    white = "#ffffff"; # colour231
    urgent = "#ffd75f"; # colour221: an urgent tab in tabbed
    critical = "#ff0000"; # colour196: chevron's banner red
    # the desktops, chadwm's onedark
    blue = "#61afef";
    red = "#e06c75";
    orange = "#caaa6a";
    green = "#7ec7a2";
    pink = "#c678dd";
    yellow = "#ebcb8b";
    # the chips
    dir = "#0087af"; # chevron's directory, colour31
    branch = "#d7005f"; # chevron's git branch, colour161
    waiting = "#ffd700"; # the tmux mark for an agent waiting on you, colour220
    working = "#585858"; # colour240
    done = "#5faf5f"; # colour71
  };

  # builtins has no toUpper, and this file evaluates without nixpkgs
  letters = s: builtins.genList (i: builtins.substring i 1 s) 26;
  upper = builtins.replaceStrings (letters "abcdefghijklmnopqrstuvwxyz") (
    letters "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
  );
  lines =
    f: builtins.concatStringsSep "" (map (n: f n colours.${n} + "\n") (builtins.attrNames colours));
  generated = "Generated from hosts/vm-aarch64/palette.nix by `just palette`: edit that file, not this one.";
in
{
  inherit colours;

  # dwm, slstatus and tabbed: a macro per colour, COL_BAR and the rest
  c =
    "/* Generated from hosts/vm-aarch64/palette.nix. */\n"
    + lines (n: v: "#define COL_${upper n} \"${v}\"");

  # rofi (configs/rofi/palette.rasi)
  rasi = "/* ${generated} */\n* {\n" + lines (n: v: "\t${n}: ${v};") + "}\n";

  # eww (configs/eww/_palette.scss)
  scss = "// ${generated}\n" + lines (n: v: "\$${n}: ${v};");

  # dunst (configs/dunst/dunstrc.d/50-palette.conf), a drop-in over dunstrc:
  # low in the bar's grey text framed in colour238, normal in colour254
  # framed in the accent, critical framed in red
  dunst =
    let
      urgency = name: fg: frame: highlight: ''
        [urgency_${name}]
            background = "${colours.bar}"
            foreground = "${fg}"
            frame_color = "${frame}"
            highlight = "${highlight}"
      '';
    in
    "# ${generated}\n\n"
    + urgency "low" colours.text colours.block colours.text
    + "\n"
    + urgency "normal" colours.bright colours.accent colours.accent
    + "\n"
    + urgency "critical" colours.bright colours.critical colours.critical;
}
