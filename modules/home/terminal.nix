{ config, ... }:

let
  dotfiles = "${config.home.homeDirectory}/src/dotfiles/configs";
in
{
  # Ghostty
  xdg.configFile."ghostty".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/ghostty";

  # WezTerm
  home.file.".wezterm.lua".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/wezterm/.wezterm.lua";

  # tmux
  xdg.configFile."tmux".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/tmux";

  # SSH config
  home.file.".ssh/config".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/ssh/config";
}
