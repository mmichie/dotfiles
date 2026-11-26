# NixOS VM — DWM tiling WM on UTM (Apple Virtualization backend, Apple Silicon)
{
  pkgs,
  lib,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # ── Nix settings ───────────────────────────────────────────────
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      trusted-users = [
        "root"
        "mim"
      ];
      auto-optimise-store = true; # Deduplicate identical files in /nix/store
      max-jobs = "auto"; # Use all CPU cores for builds
    };
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 7d";
    };
  };

  nixpkgs.config.allowUnfree = true;

  # ── Networking ─────────────────────────────────────────────────
  networking = {
    hostName = "vm-aarch64";
    nameservers = [
      "8.8.8.8"
      "8.8.4.4"
    ];
    networkmanager = {
      enable = true;
      dns = "none"; # Don't let NM overwrite resolv.conf
    };
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ]; # SSH only
    };
  };

  # ── Time & locale ──────────────────────────────────────────────
  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";

  # ── Shared folders (UTM VirtioFS) ──────────────────────────────
  # UTM puts every directory shared with the VM behind one virtiofs device
  # tagged "share", each as a sub-directory named after the directory itself.
  # No uid or gid mapping: Apple's VirtioFS shows a file as owned by whichever
  # guest user is asking and does the work on the Mac as the user running UTM,
  # so mim reads and writes the share as is. nofail: with nothing shared the
  # device does not exist, and the boot must not stop on it.
  fileSystems."/mnt/utm" = {
    device = "share";
    fsType = "virtiofs";
    options = [ "nofail" ];
  };

  # Symlink ~/src → /mnt/utm/src so the Mac's ~/src appears in the home dir
  systemd.tmpfiles.rules = [
    "L /home/mim/src - - - - /mnt/utm/src"
  ];

  # ── Graphics (Mesa OpenGL) ─────────────────────────────────────
  # Software rendering (llvmpipe): the Apple backend gives a Linux guest a
  # virtio-gpu display with no 3D acceleration.
  hardware.graphics.enable = true;

  # ── X11 + DWM ──────────────────────────────────────────────────
  services = {
    xserver = {
      enable = true;
      xkb.layout = "us";
      dpi = 96; # Native resolution (no HiDPI scaling)

      # dwm/config.h is the whole configuration: upstream's defaults with
      # Super as the modifier and the look (colours, font, borders, gaps).
      # The patches add what a config.h cannot: gaps, a colour scheme of
      # its own for the window title, restarting in place (which loads a new
      # dwm without closing any window), colours in the status text, the
      # title centred on the screen, and the bar's look (its height, inset
      # status blocks, tags drawn by state). Its tags, window rules
      # and per-tag keys come from desktops.h, generated from the desktops
      # shared with AeroSpace (lib/desktops.nix).
      windowManager.dwm = {
        enable = true;
        package =
          (pkgs.dwm.override {
            conf = ./dwm/config.h;
            patches = [
              ./dwm/gaps.diff
              ./dwm/titlescheme.diff
              ./dwm/restartsig.diff
              ./dwm/status2d.diff
              ./dwm/centeredwindowname.diff
              ./dwm/barstyle.diff
            ];
          }).overrideAttrs
            (old: {
              # nixpkgs' postPatch (the copy of config.h) ends without a
              # newline, so each command gets a line of its own
              postPatch = ''
                ${old.postPatch}
                cp ${pkgs.callPackage ./dwm/desktops.nix { }} desktops.h
              '';
              # libXcursor, for themed cursors (see Cursor below)
              postFixup = (old.postFixup or "") + ''
                patchelf --add-needed libXcursor.so.1 --add-rpath ${lib.getLib pkgs.libxcursor}/lib $out/bin/dwm
              '';
            });
      };

      # Auto-login — single-user VM, skip the login screen
      displayManager = {
        lightdm.enable = true;
        sessionCommands = ''
          # 1x: the guest is drawn pixel-for-pixel on the 3440x1440 monitor.
          # DPI is the only font setting that belongs here. Antialiasing,
          # hinting and subpixel order are set through fonts.fontconfig below:
          # fontconfig puts them on every pattern, and libXft reads an Xft.*
          # resource only for a property the pattern lacks, so setting them
          # here did nothing for dwm, st or dmenu.
          xrdb -merge <<XEOF
          Xft.dpi: 96
          XEOF

          # Keep the display on. X blanked it and powered the virtual monitor
          # off after ten idle minutes, and the guest sees input only while
          # its UTM window has focus, so it went black in plain view while the
          # work was on the Mac. The Mac's own screen lock still applies.
          xset s off -dpms

          # Clipboard: the per-session half of the SPICE agent (the system
          # half is services.spice-vdagentd). It exits at once when clipboard
          # sharing is off in UTM.
          spice-vdagent

          # Follow the UTM window. With Dynamic Resolution on (UTM's default)
          # the virtual display is resized to fit the window, full screen
          # included, and the guest sees each new size as a monitor hotplug
          # carrying a new preferred mode. Nothing in a bare dwm session acts
          # on one, so apply it here; the guest then always renders at the
          # window's own pixel size.
          udevadm monitor --udev --subsystem-match=drm | while read -r _; do
            xrandr --output Virtual-1 --auto
          done &

          # Wallpaper, which shows in the gaps around windows. --daemon forks
          # and stays to redraw it at every new display size from the loop
          # above; without it a bigger root window would tile the old image.
          ${lib.getExe pkgs.xwallpaper} --daemon --zoom ${pkgs.nixos-artwork.wallpapers.nineish-dark-gray.gnomeFilePath}

          # Notifications, in the bar's colours (configs/dunst, linked by
          # home.nix). No compositor: picom, tried here, left terminals
          # undrawn after a switch of desktops.
          ${lib.getExe pkgs.dunst} &

          # dwm's status text: CPU, memory and disk use, date and time, each
          # a label or icon on the bar's accent beside its value on grey,
          # refreshed every second (slstatus/config.h).
          ${lib.getExe (pkgs.slstatus.override { conf = ./slstatus/config.h; })} &
        '';
      };
    };

    displayManager = {
      defaultSession = "none+dwm";
      autoLogin = {
        enable = true;
        user = "mim";
      };
    };

    # ── Clipboard ──────────────────────────────────────────────────
    # Shared with macOS through UTM (Virtualization > Enable Clipboard
    # Sharing). This is the system half of the SPICE agent; the session half
    # starts with the X session above.
    spice-vdagentd.enable = true;

    # ── mDNS ───────────────────────────────────────────────────────
    # Announce vm-aarch64.local. UTM's shared network hands out the address
    # by DHCP, so the Mac's `ssh vm` alias uses this name rather than a number.
    avahi = {
      enable = true;
      settings.publish = {
        disable-publishing = false;
        publish-addresses = true;
      };
    };

    # ── Audio ──────────────────────────────────────────────────────
    pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };

    # ── SSH ─────────────────────────────────────────────────────────
    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false; # Key-only — no brute-force risk
        PermitRootLogin = "no"; # Root can't SSH in
        KbdInteractiveAuthentication = false;
      };
    };
  };

  # ── Fonts ──────────────────────────────────────────────────────
  fonts = {
    enableDefaultPackages = false; # Only install what we declare
    packages = with pkgs; [
      nerd-fonts.hack
      nerd-fonts.iosevka
      nerd-fonts.jetbrains-mono
      dejavu_fonts
      liberation_ttf
      # fontconfig's default emoji family. Without it st draws any emoji the
      # other fonts lack as an empty box.
      noto-fonts-color-emoji
    ];

    # Subpixel antialiasing, for an RGB-stripe LCD shown 1:1: the Acer X34 at
    # its native 3440x1440 and 96 dpi. NixOS defaults to grayscale. The rest
    # of the defaults already fit (antialiasing on, slight hinting, default
    # LCD filter); full hinting was measured against slight and renders Hack
    # almost identically. Colour fringes on text mean this no longer matches
    # the display: use "bgr" for a reversed stripe, "none" if the guest is
    # scaled or on a Retina or OLED panel.
    fontconfig.subpixel.rgba = "rgb";
  };

  # ── Cursor ─────────────────────────────────────────────────────
  # The theme every X client falls back to when nothing names one, Xcursor's
  # "default". There was none.
  #
  # That alone does not reach dwm and st, which drew X's core bitmap cursors
  # either way: they ask X for its core cursors, which libX11 themes through
  # libXcursor, but libX11 dlopens that by name from its own library paths,
  # where NixOS does not put it. So both builds (dwm above, st below) load it
  # at startup, and the dlopen finds it already loaded. Adwaita has no
  # "sizing", dwm's resize cursor, so that one stays X's.
  #
  # adwaita-icon-theme is declared in the packages below: until now only the
  # LightDM greeter's module happened to install it.
  xdg.icons.fallbackCursorThemes = [ "Adwaita" ];

  # ── GTK ────────────────────────────────────────────────────────
  # Prefer dark, like dwm's bar. Unset, GTK defaults to light, and Chrome
  # follows GTK: it drew a light UI and told the pages it shows
  # prefers-color-scheme: light. GTK reads these through XDG_CONFIG_DIRS,
  # which starts with /etc/xdg.
  environment.etc = lib.genAttrs [ "xdg/gtk-3.0/settings.ini" "xdg/gtk-4.0/settings.ini" ] (_: {
    text = ''
      [Settings]
      gtk-application-prefer-dark-theme=1
    '';
  });

  # ── System packages ────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    curl
    (st.overrideAttrs (old: {
      # suckless terminal with Nerd Font, in Ghostty's colours (st/colors.diff)
      patches = (old.patches or [ ]) ++ [
        (pkgs.writeText "font.patch" ''
          diff --git a/config.def.h b/config.def.h
          --- a/config.def.h
          +++ b/config.def.h
          @@ -7,1 +7,1 @@
          -static char *font = "Liberation Mono:pixelsize=12:antialias=true:autohint=true";
          +static char *font = "Hack Nerd Font:size=11:antialias=true:autohint=false";
        '')
        ./st/colors.diff
      ];
      # libXcursor, for themed cursors (see Cursor above)
      postFixup = (old.postFixup or "") + ''
        patchelf --add-needed libXcursor.so.1 --add-rpath ${lib.getLib libxcursor}/lib $out/bin/st
      '';
    }))
    adwaita-icon-theme # the cursor theme (xdg.icons above)
    # DWM launcher; -h, which dwm passes, makes its line as tall as the bar
    (dmenu.override { patches = [ ./dmenu/lineheight.diff ]; })
    # The themed launcher, Mod+R (configs/rofi)
    rofi
    # Tabs around st, Mod+Shift+T, in the tmux theme's colours
    (tabbed.override { customConfig = builtins.readFile ./tabbed/config.h; })
    # Started with the X session above; here for dunstctl
    dunst
    # Google's own arm64 build (unfree, allowed above), so not in the
    # binary cache: a switch fetches the .deb from Google and repackages it.
    # dmenu finds it as google-chrome-stable.
    google-chrome
    # Slack and Spotify as their web apps, each in its own Chrome app window.
    # Both desktop apps wrap these same web UIs in a bundled Chromium, but
    # they publish that bundle for Linux only on x86_64 (Slack an amd64 .deb,
    # Spotify an amd64 snap), so nixpkgs has neither for aarch64-linux.
    # Spotify's player needs Widevine, which this Chrome ships.
    (writeShellScriptBin "slack" ''
      exec ${lib.getExe google-chrome} --app=https://app.slack.com/client "$@"
    '')
    (writeShellScriptBin "spotify" ''
      exec ${lib.getExe google-chrome} --app=https://open.spotify.com "$@"
    '')
    xclip
    xsel
    xdotool # dwm's Cmd+C / Cmd+V (dwm/config.h)
  ];

  # ── User ───────────────────────────────────────────────────────
  users = {
    users.mim = {
      isNormalUser = true;
      initialPassword = "nixos"; # Change after first login with `passwd`
      extraGroups = [
        "wheel"
        "networkmanager"
        "video"
      ];
      shell = pkgs.zsh;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFu6EGwcAtua7e2eBu3KNTGdBKP+0UOim1M0cvZgzF6U"
      ];
    };
    mutableUsers = true; # Allow passwd changes; remove initialPassword
  };

  programs = {
    zsh = {
      enable = true;
      # Same rationale as darwin: ~/.zshrc runs its own fingerprinted compinit;
      # the global one in /etc/zshrc would be a second, slower compinit.
      enableGlobalCompInit = false;
      # And as on darwin: no bashcompinit (nothing uses bash-style completions),
      # no global prompt theme (lib/60-prompt.zsh replaces it anyway).
      enableBashCompletion = false;
      promptInit = "";
    };

    # 1Password's own arm64 build (unfree). The NixOS module rather than a
    # bare package: it installs the polkit policy that lets mim unlock the
    # app with the account password, which home-manager cannot do.
    _1password-gui = {
      enable = true;
      polkitPolicyOwners = [ "mim" ];
    };
  };

  # ── Security ───────────────────────────────────────────────────
  security.sudo.wheelNeedsPassword = false; # Single-user dev VM

  # ── Kernel hardening ───────────────────────────────────────────
  boot = {
    kernelModules = [ "tcp_bbr" ];
    kernel.sysctl = {
      # Disable Magic SysRq key
      "kernel.sysrq" = 0;

      ## TCP hardening
      "net.ipv4.icmp_ignore_bogus_error_responses" = 1; # Prevent bogus ICMP log spam
      "net.ipv4.conf.default.rp_filter" = 1; # Reverse-path filtering (anti-spoof)
      "net.ipv4.conf.all.rp_filter" = 1;
      "net.ipv4.conf.all.accept_source_route" = 0; # Not a router
      "net.ipv6.conf.all.accept_source_route" = 0;
      "net.ipv4.conf.all.send_redirects" = 0; # Not a router
      "net.ipv4.conf.default.send_redirects" = 0;
      "net.ipv4.conf.all.accept_redirects" = 0; # MITM mitigation
      "net.ipv4.conf.default.accept_redirects" = 0;
      "net.ipv4.conf.all.secure_redirects" = 0;
      "net.ipv4.conf.default.secure_redirects" = 0;
      "net.ipv6.conf.all.accept_redirects" = 0;
      "net.ipv6.conf.default.accept_redirects" = 0;
      "net.ipv4.tcp_syncookies" = 1; # SYN flood protection
      "net.ipv4.tcp_rfc1337" = 1; # TIME-WAIT assassination protection

      ## TCP optimization
      "net.ipv4.tcp_fastopen" = 3; # TFO for incoming + outgoing
      "net.ipv4.tcp_congestion_control" = "bbr"; # Better congestion control
      "net.core.default_qdisc" = "cake"; # Bufferbloat mitigation
    };
  };

  # ── State version ──────────────────────────────────────────────
  system.stateVersion = "25.05";
}
