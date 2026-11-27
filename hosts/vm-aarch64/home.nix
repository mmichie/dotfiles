# home-manager additions for the vm-aarch64 guest alone (flake.nix passes this
# as an extra home module): the config files of its X desktop, linked from
# configs/ like the rest so an edit is live without a rebuild, and a few
# terminal programs for it.
{ mkLink, pkgs, ... }:
let
  # Publishes a terminal's chips for dwm's bar (dwm/chips.sh): run by the zsh
  # prompt, by tmux's focus hooks, and by the agent hook below.
  dwm-chips = pkgs.writeShellApplication {
    name = "dwm-chips";
    runtimeInputs = with pkgs; [
      git
      tmux
      xprop
    ];
    text = builtins.readFile ./dwm/chips.sh;
  };

  # The desktop's menus and dashboard widgets (scripts/): the power and
  # screenshot menus, Mod+Shift+E and Mod+Shift+S in dwm/config.h, and the
  # dashboard's music and GitHub sections (configs/eww). rofi and systemctl
  # come from the system's PATH: rofi with its plugins, systemctl the running
  # systemd's.
  script =
    name: file: runtimeInputs:
    pkgs.writeShellApplication {
      inherit name runtimeInputs;
      text = builtins.readFile file;
    };
  scripts = with pkgs; [
    (script "rofi-power" ./scripts/power.sh [
      gawk
      procps
    ])
    (script "rofi-screenshot" ./scripts/screenshot.sh [
      maim
      xdotool
      xclip
      libnotify
    ])
    (script "eww-music" ./scripts/music.sh [
      playerctl
      curl
      jq
    ])
    (script "eww-github" ./scripts/github.sh [
      curl
      gawk
      gnused
      gnugrep
    ])
  ];
in
{
  xdg.configFile = {
    # Notifications, started with the X session (configuration.nix), the
    # launcher, and the dashboard.
    "dunst".source = mkLink "dunst";
    "rofi".source = mkLink "rofi";
    "eww".source = mkLink "eww";
    # An agent's state for dwm's chips. bin/bin/claude-tmux-state runs each
    # hook here as `<hook> <agent> <state>` before it records the state on
    # the pane, so this passes the new one along; - changes nothing.
    "agent-hooks.d/dwm-chips".source = pkgs.writeShellScript "agent-hook-dwm-chips" ''
      case $2 in
      -) exit 0 ;;
      clear) state= ;;
      *) state=$2 ;;
      esac
      exec ${dwm-chips}/bin/dwm-chips --tmux "''${TMUX%%,*}" "$TMUX_PANE" "$state"
    '';
  };

  home.packages = [
    dwm-chips
  ]
  ++ scripts
  ++ (with pkgs; [
    asciiquarium # an aquarium in the terminal
    yazi # a terminal file manager with image previews (Ghostty's graphics)
  ]);
}
