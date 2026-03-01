{ pkgs, self, ... }:

{
  imports = [
    ../../modules/darwin/defaults.nix
    ../../modules/darwin/homebrew.nix
  ];

  # Determinate Systems manages the Nix daemon — disable nix-darwin's management
  nix.enable = false;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # System-level packages (available to all users)
  environment.systemPackages = with pkgs; [
    vim
    git
  ];

  # Touch ID for sudo (reattach fixes it inside tmux)
  security.pam.services.sudo_local.touchIdAuth = true;
  security.pam.services.sudo_local.reattach = true;

  # Enable zsh as default shell
  programs.zsh.enable = true;

  # Primary user (required for user-scoped defaults, homebrew, etc.)
  system.primaryUser = "mim";

  # Networking
  networking.hostName = "mims-mbp";

  # Copy nix apps to /Applications so Spotlight can index them
  # (symlinks into /nix/store are invisible to Spotlight)
  system.activationScripts.applications.text =
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

  # Used for backwards compatibility
  system.stateVersion = 6;

  # Platform
  nixpkgs.hostPlatform = "aarch64-darwin";
}
