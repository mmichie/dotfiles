{ mkLink, ... }:
{
  home.file = {
    ".zshenv".source = mkLink "zsh/.zshenv";
    ".zshrc".source = mkLink "zsh/.zshrc";
    ".zsh".source = mkLink "zsh/.zsh";
  };

  xdg.configFile."direnv".source = mkLink "direnv";
}
