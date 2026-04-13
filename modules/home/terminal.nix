{ config, ... }:
{
  xdg.configFile."ghostty".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesPath}/ghostty";
  home.file.".wezterm.lua".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesPath}/wezterm/.wezterm.lua";
  xdg.configFile."tmux".source = config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesPath}/tmux";
  home.file.".ssh/config".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesPath}/ssh/config";
}
