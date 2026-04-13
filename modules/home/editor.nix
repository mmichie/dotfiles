{ config, ... }:
{
  xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesPath}/nvim";
}
