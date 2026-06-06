_:

{
  # Homebrew is used only for casks (GUI apps) — CLI tools come from nixpkgs
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "uninstall"; # Remove casks not listed here (zap breaks docker-desktop receipt)
      # Homebrew 5.1.15 made --cleanup interactive; this restores the old
      # non-prompting uninstall. Drop once nix-darwin#1787 is fixed upstream.
      extraFlags = [ "--force-cleanup" ];
    };

    taps = [
      "nikitabobko/tap"
      "tensor9ine/tensor9"
    ];

    brews = [
      "dosbox-x" # nixpkgs build broken on aarch64-darwin (SCREEN_METAL undeclared in render.cpp)
      "tensor9ine/tensor9/tensor9"
    ];

    casks = [
      # Browsers
      "google-chrome"

      # Terminals
      "ghostty"

      # Development
      "claude"
      "docker-desktop"
      # "vmware-fusion"  # Broadcom download server broken
      "zed"

      # Productivity
      "obsidian"
      "discord"
      "signal"
      "slack"
      "zoom"
      "1password"

      # Window Management
      "nikitabobko/tap/aerospace"
      "karabiner-elements"

      # Media
      "vlc"
      "iina"
      "obs"
      "spotify"
      "handbrake-app"
      "gimp"

      # Utilities
      "keybase"
      "wireshark-app"
      "tailscale-app"
      "hazeover"
      "scroll-reverser"
      "selfcontrol"
      "keka"
      "fuse-t"
      "veracrypt-fuse-t"

      # Gaming
      "steam"
      "nvidia-geforce-now"
    ];
  };
}
