{ ... }:

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
    ];

    casks = [
      # Browsers
      "google-chrome"

      # Terminals
      "ghostty"

      # Development
      { name = "docker-desktop"; greedy = true; }
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

      # Utilities
      "wireshark-app"
      "tailscale-app"
      "hazeover"
      "scroll-reverser"
      "keka"

      # Gaming
      "steam"
      "nvidia-geforce-now"

      # Fonts
      "font-hack-nerd-font"
      "font-iosevka"
    ];
  };
}
