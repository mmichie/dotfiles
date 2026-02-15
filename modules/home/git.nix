{ config, ... }:

let
  dotfiles = "${config.home.homeDirectory}/src/dotfiles/configs";
in
{
  home.file.".gitconfig".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/git/.gitconfig";
  home.file.".gitignore_global".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/git/.gitignore_global";
}
