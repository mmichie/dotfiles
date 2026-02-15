{ pkgs, self, ... }:

{
  imports = [
    ../../modules/darwin/defaults.nix
    ../../modules/darwin/homebrew.nix
  ];

  # Nix settings
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "mim" ];
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # System-level packages (available to all users)
  environment.systemPackages = with pkgs; [
    vim
    git
  ];

  # Enable zsh as default shell
  programs.zsh.enable = true;

  # Networking
  networking.hostName = "mims-mbp";

  # Used for backwards compatibility
  system.stateVersion = 6;

  # Platform
  nixpkgs.hostPlatform = "aarch64-darwin";
}
