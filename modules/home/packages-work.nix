{
  pkgs,
  lib,
  config,
  ...
}:
{
  home.packages = lib.mkIf config.my.isWork (
    with pkgs;
    [
      # Work-specific CLI tools
    ]
  );
}
