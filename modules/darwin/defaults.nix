_:

{
  # ── General UI/UX ──────────────────────────────────────────────────
  system = {
    defaults = {
      NSGlobalDomain = {
        # Dark mode
        AppleInterfaceStyle = "Dark";

        # Disable opening and closing window animations
        NSAutomaticWindowAnimationsEnabled = false;

        # Fast window resize
        NSWindowResizeTime = 1.0e-3;

        # Expand save panel by default
        NSNavPanelExpandedStateForSaveMode = true;
        NSNavPanelExpandedStateForSaveMode2 = true;

        # Expand print panel by default
        PMPrintingExpandedStateForPrint = true;
        PMPrintingExpandedStateForPrint2 = true;

        # Save to disk (not to iCloud) by default
        NSDocumentSaveNewDocumentsToCloud = false;

        # Show all filename extensions
        AppleShowAllExtensions = true;

        # Full keyboard access for all controls
        AppleKeyboardUIMode = 2;

        # Disable press-and-hold for keys in favor of key repeat
        ApplePressAndHoldEnabled = false;

        # Fast key repeat rate
        InitialKeyRepeat = 35;

        # Disable auto-correct
        NSAutomaticSpellingCorrectionEnabled = false;

        # Natural scrolling
        "com.apple.swipescrolldirection" = true;

        # Spring loading for directories
        "com.apple.springing.enabled" = true;
        "com.apple.springing.delay" = 0.5;
      };

      # ── Login window ─────────────────────────────────────────────────
      loginwindow = {
        GuestEnabled = false; # Disable guest account
        DisableConsoleAccess = true; # Disable >console login
      };

      # ── Screensaver / Lock ──────────────────────────────────────────
      screensaver = {
        askForPassword = true; # Require password after screensaver
        askForPasswordDelay = 0; # No grace period
      };

      # ── Dock ───────────────────────────────────────────────────────────
      dock = {
        tilesize = 57;
        launchanim = false;
        expose-animation-duration = 0.1;
        minimize-to-application = true;
        mineffect = "scale";
        autohide = true;
        autohide-delay = 1000.0;
        autohide-time-modifier = 0.0;
        mru-spaces = false;
      };

      # ── Finder ─────────────────────────────────────────────────────────
      finder = {
        AppleShowAllExtensions = true;
        FXEnableExtensionChangeWarning = false;
        FXPreferredViewStyle = "Nlsv";
        ShowExternalHardDrivesOnDesktop = true;
        ShowHardDrivesOnDesktop = true;
        ShowRemovableMediaOnDesktop = true;
        _FXShowPosixPathInTitle = false;
      };

      # ── Screenshots ────────────────────────────────────────────────────
      screencapture = {
        location = "~/Documents/Screenshots";
        type = "png";
      };

      # ── Spaces ─────────────────────────────────────────────────────────
      spaces.spans-displays = true;

      # ── Software updates ──────────────────────────────────────────────
      # Declared so a fresh machine matches this one: check, download and
      # install macOS updates (including the background security and XProtect
      # configuration data) and App Store updates without waiting to be asked.
      SoftwareUpdate.AutomaticallyInstallMacOSUpdates = true;
      CustomSystemPreferences = {
        "com.apple.SoftwareUpdate" = {
          AutomaticCheckEnabled = true;
          AutomaticDownload = true;
          CriticalUpdateInstall = true;
          ConfigDataInstall = true;
        };
        "com.apple.commerce" = {
          AutoUpdate = true;
        };
      };

      # ── Custom preferences ─────────────────────────────────────────────
      CustomUserPreferences = {
        "com.apple.LaunchServices" = {
          # Quarantine ON. Downloads keep their quarantine tag, so the first
          # open of a downloaded app still gets Gatekeeper's signature and
          # notarization check behind the "downloaded from the Internet"
          # prompt. This was false (a copied default that removed that check);
          # written explicitly rather than deleted because nix-darwin never
          # unsets a key it stops declaring.
          LSQuarantine = true;
        };
        "com.apple.ActivityMonitor" = {
          ShowCategory = 109;
        };
        "com.apple.desktopservices" = {
          DSDontWriteNetworkStores = true;
          DSDontWriteUSBStores = true;
        };
        "com.apple.finder" = {
          DisableAllAnimations = true;
        };
        "org.eyebeam.SelfControl" = {
          Blocklist = [
            "facebook.com"
            "instagram.com"
            "twitter.com"
            "x.com"
            "reddit.com"
          ];
        };
      };
    };
  };

  # ── Firewall ──────────────────────────────────────────────────────
  networking.applicationFirewall = {
    enable = true; # Enable firewall
    enableStealthMode = true; # Stealth mode — drop unsolicited inbound
    allowSignedApp = true; # Allow signed apps through
  };
}
