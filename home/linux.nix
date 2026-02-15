{ pkgs, config, ... }:

{
  home.username = "mim";
  home.homeDirectory = "/home/mim";
  home.stateVersion = "24.11";

  # Linux-specific packages
  home.packages = with pkgs; [
    xclip
    xsel
  ];
}
