{ ... }:

{
  # Homebrew is used only for casks (GUI apps) — CLI tools come from nixpkgs
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap"; # Remove casks not listed here
    };

    taps = [
      "nikitabobko/tap"
    ];

    casks = [
      # Browsers
      "google-chrome"

      # Terminals
      "ghostty"
      "wezterm"

      # Development
      "docker-desktop"
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
      "spotify"
      "handbrake"

      # Utilities
      "tailscale"
      "hazeover"
      "scroll-reverser"
      "keka"

      # Gaming
      "steam"

      # Fonts
      "font-hack-nerd-font"
      "font-iosevka"
    ];
  };
}
