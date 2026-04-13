{ lib, config, ... }:
{
  options.my = {
    dotfilesRoot = lib.mkOption {
      type = lib.types.str;
      default = "${config.home.homeDirectory}/src/dotfiles";
      description = "Path to the dotfiles repository root.";
    };

    dotfilesPath = lib.mkOption {
      type = lib.types.str;
      default = "${config.my.dotfilesRoot}/configs";
      description = "Path to the dotfiles configs directory.";
    };

    user = {
      name = lib.mkOption {
        type = lib.types.str;
        default = "mim";
        description = "Primary username.";
      };

      stateVersion = lib.mkOption {
        type = lib.types.str;
        default = "24.11";
        description = "Home-manager state version.";
      };
    };
  };
}
