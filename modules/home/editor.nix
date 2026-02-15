{ config, ... }:

let
  dotfiles = "${config.home.homeDirectory}/src/dotfiles/configs";
in
{
  # Neovim — full config dir symlinked for live editing
  xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/nvim";
}
