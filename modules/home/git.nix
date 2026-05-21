{
  lib,
  config,
  mkLink,
  ...
}:
{
  home.file = {
    ".gitconfig".source = mkLink "git/.gitconfig";
    ".gitignore_global".source = mkLink "git/.gitignore_global";
  }
  // lib.optionalAttrs config.my.isWork {
    ".gitconfig-kyusu-local".source = mkLink "git/.gitconfig-kyusu-local";
  };
}
