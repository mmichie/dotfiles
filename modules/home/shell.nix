{ mkLink, ... }:
{
  home.file.".zshrc".source = mkLink "zsh/.zshrc";
  home.file.".zsh".source = mkLink "zsh/.zsh";

  xdg.configFile."direnv".source = mkLink "direnv";
}
