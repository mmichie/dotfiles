{
  pkgs,
  config,
  self,
  starship-segments,
  ...
}:

let
  dotfiles = "${config.home.homeDirectory}/src/dotfiles";
in
{
  home.username = "mim";
  home.stateVersion = "24.11";

  # Let home-manager manage itself
  programs.home-manager.enable = true;

  # Put starship-segments binary on PATH
  home.packages = [
    starship-segments
  ];

  # ~/bin — scripts and platform binaries
  home.file."bin".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/bin/bin";

  # System-level dotfiles
  home.file.".inputrc".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/configs/system/.inputrc";
  home.file.".dircolors".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/configs/system/.dircolors";
  home.file.".tmux-cht-command".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/configs/system/.tmux-cht-command";
  home.file.".tmux-cht-languages".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/configs/system/.tmux-cht-languages";

  # Clima config
  xdg.configFile."clima".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/configs/system/clima";
  xdg.configFile."location".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/configs/system/location";
}
