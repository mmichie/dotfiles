{ mkLink, ... }:
{
  home.file.".gitconfig".source = mkLink "git/.gitconfig";
  home.file.".gitignore_global".source = mkLink "git/.gitignore_global";
  home.file.".gitconfig-kyusu-local".source = mkLink "git/.gitconfig-kyusu-local";
}
