_:

{
  # Homebrew is used only for casks (GUI apps) — CLI tools come from nixpkgs
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "uninstall"; # Remove casks not listed here (zap breaks docker-desktop receipt)
    };

    taps = [
      "nikitabobko/tap"
      "tensor9ine/tensor9"
    ];

    brews = [
      "dosbox-x"
    ];

    casks = [
      # Browsers
      "google-chrome"

      # Terminals
      "ghostty"

      # Development
      # "docker-desktop"  # Homebrew cask install bug — manage manually
      # "vmware-fusion"  # Broadcom download server broken
      "zed"

      # Productivity
      "obsidian"
      "discord"
      "signal"
      "slack"
      "zoom"
      "1password"
      "1password-cli"

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
      "keka"
      "fuse-t"
      "veracrypt-fuse-t"

      # Gaming
      "steam"
      "nvidia-geforce-now"

      # Fonts
      "font-hack-nerd-font"
      "font-iosevka"
    ];
  };
}
