{ mkLink, ... }:
{
  home.file = {
    ".zshenv".source = mkLink "zsh/.zshenv";
    ".zprofile".source = mkLink "zsh/.zprofile";
    ".zshrc".source = mkLink "zsh/.zshrc";
    ".zsh".source = mkLink "zsh/.zsh";
  };

  xdg.configFile."direnv".source = mkLink "direnv";
}
