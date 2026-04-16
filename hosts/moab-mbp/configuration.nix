{ pkgs, self, ... }:

{
  imports = [
    ../../modules/darwin/defaults.nix
    ../../modules/darwin/homebrew.nix
  ];

  nix.enable = false;

  launchd.daemons.nix-gc = {
    command = "/nix/var/nix/profiles/default/bin/nix-collect-garbage --delete-older-than 30d";
    serviceConfig = {
      RunAtLoad = false;
      StartCalendarInterval = [
        {
          Weekday = 0;
          Hour = 2;
          Minute = 0;
        }
      ];
    };
  };

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    vim
    git
  ];

  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true;
  };

  programs.zsh.enable = true;

  system = {
    primaryUser = "mim";

    activationScripts.applications.text =
      let
        apps = pkgs.buildEnv {
          name = "system-apps";
          paths = with pkgs; [ wezterm ];
          pathsToLink = [ "/Applications" ];
        };
      in
      pkgs.lib.mkForce ''
        echo "setting up /Applications/Nix Apps..." >&2
        app_dir="/Applications/Nix Apps"
        rm -rf "$app_dir"
        mkdir -p "$app_dir"
        for app in ${apps}/Applications/*; do
          cp -rL "$app" "$app_dir/$(basename "$app")"
        done
      '';

    stateVersion = 6;
  };

  networking.hostName = "moab-mbp";
  nixpkgs.hostPlatform = "aarch64-darwin";
}
