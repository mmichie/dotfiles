{ lib, config, ... }:
let
  inherit (import ../../lib/options.nix { inherit lib; }) mkOpt' mkBoolOpt;
in
{
  options.my = {
    dotfilesRoot =
      mkOpt' lib.types.str "${config.home.homeDirectory}/src/dotfiles"
        "Path to the dotfiles repository root.";

    dotfilesPath =
      mkOpt' lib.types.str "${config.my.dotfilesRoot}/configs"
        "Path to the dotfiles configs directory.";

    user = {
      name = mkOpt' lib.types.str "mim" "Primary username.";
      stateVersion = mkOpt' lib.types.str "24.11" "Home-manager state version.";
    };

    sops = {
      keyFile =
        mkOpt' lib.types.str "${config.home.homeDirectory}/.config/sops/age/keys.txt"
          "Path to the age private key used to decrypt sops-encrypted secrets.";
    };

    isWork = mkBoolOpt false "Whether this host is a work machine (gates work-only secrets and tooling).";
  };
}
