{ mkLink, ... }:
{
  home.file.".gitconfig".source = mkLink "git/.gitconfig";
  home.file.".gitignore_global".source = mkLink "git/.gitignore_global";
}
