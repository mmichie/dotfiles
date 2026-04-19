{
  pkgs,
  mkLink,
  ...
}:
{
  home.packages = with pkgs; [
    pinentry_mac
    terminal-notifier
  ];

  xdg.configFile."aerospace".source = mkLink "aerospace";
  xdg.configFile."karabiner".source = mkLink "karabiner";
}
