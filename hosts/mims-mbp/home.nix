{ pkgs, lib, config, self, ... }:

let
  dotfiles = "${config.home.homeDirectory}/src/dotfiles/configs";
in
{
  home.homeDirectory = lib.mkForce "/Users/mim";

  # macOS-specific home-manager settings

  # macOS-only packages
  home.packages = with pkgs; [
    pinentry_mac
    terminal-notifier
  ];

  # Aerospace (macOS tiling WM)
  xdg.configFile."aerospace".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/aerospace";

  # Karabiner (macOS keyboard customization)
  xdg.configFile."karabiner".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/karabiner";
}
