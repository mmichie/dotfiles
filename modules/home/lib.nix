{ config, ... }:
{
  _module.args.mkLink = path: config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesPath}/${path}";
}
