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

      # Keep "uninstall" cleanup for casks/brews/taps, but DON'T let it remove
      # App Store apps missing from masApps. Adding masApps pulled mas into
      # Homebrew's cleanup, which silently removed manually-installed MAS apps
      # (nix-darwin assumes Homebrew never cleans mas; current Homebrew does).
      # brew bundle reads this env var via onActivation.extraEnv.
      extraEnv.HOMEBREW_BUNDLE_CLEANUP_NO_MAS = "1";
    };

    taps = [
      "nikitabobko/tap"
      "tensor9ine/tensor9"
    ];

    brews = [
      "dosbox-x" # nixpkgs build broken on aarch64-darwin (SCREEN_METAL undeclared in render.cpp)
      "mas" # Mac App Store CLI — required for the masApps below
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

    # Mac App Store apps, installed via `mas`. Requires being signed into the
    # App Store, and `mas` can only install apps already in this Apple ID's
    # purchase history — current macOS won't let it acquire a never-obtained
    # app, so "Get" it once in the App Store GUI before the first switch.
    masApps = {
      "Amphetamine" = 937984704; # keep-the-Mac-awake utility
      "Amazon Kindle" = 302584613;
      "OmniGraffle 7" = 1142578753; # MAS license only — won't install if bought via Omni direct
      "Monodraw" = 920404675; # paid — installs only if already owned on this Apple ID
      "WireGuard" = 1451685025;
    };
  };
}
