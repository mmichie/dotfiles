{
  pkgs,
  config,
  ...
}:
{
  home.packages = with pkgs; [
    pinentry_mac
    terminal-notifier
  ];

  xdg.configFile."aerospace".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesPath}/aerospace";
  xdg.configFile."karabiner".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesPath}/karabiner";
}
