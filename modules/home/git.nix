{ config, ... }:
{
  home.file.".gitconfig".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesPath}/git/.gitconfig";
  home.file.".gitignore_global".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesPath}/git/.gitignore_global";
}
