# home-manager additions for the vm-aarch64 guest alone (flake.nix passes this
# as an extra home module): the config files of its X desktop, linked from
# configs/ like the rest so an edit is live without a rebuild, and a few
# terminal programs for it.
{ mkLink, pkgs, ... }:
{
  xdg.configFile = {
    # Notifications, started with the X session (configuration.nix), and
    # the launcher.
    "dunst".source = mkLink "dunst";
    "rofi".source = mkLink "rofi";
  };

  home.packages = with pkgs; [
    fastfetch # system information beside a logo
    asciiquarium # an aquarium in the terminal
    yazi # a terminal file manager with image previews (Ghostty's graphics)
  ];
}
