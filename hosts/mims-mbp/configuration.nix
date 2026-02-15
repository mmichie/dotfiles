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

  # Enable zsh as default shell
  programs.zsh.enable = true;

  # Primary user (required for user-scoped defaults, homebrew, etc.)
  system.primaryUser = "mim";

  # Networking
  networking.hostName = "mims-mbp";

  # Used for backwards compatibility
  system.stateVersion = 6;

  # Platform
  nixpkgs.hostPlatform = "aarch64-darwin";
}
