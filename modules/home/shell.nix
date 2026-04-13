{ config, ... }:
{
  home.file.".zshrc".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesPath}/zsh/.zshrc";
  home.file.".zsh".source = config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesPath}/zsh/.zsh";

  xdg.configFile."direnv".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesPath}/direnv";
  xdg.configFile."starship.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesPath}/starship/starship.toml";
}
