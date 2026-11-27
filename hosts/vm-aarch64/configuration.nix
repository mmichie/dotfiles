# NixOS VM — DWM tiling WM on UTM (Apple Virtualization backend, Apple Silicon)
{
  pkgs,
  lib,
  ...
}:

let
  # The desktop's colours (palette.nix), as the C header dwm, slstatus and
  # tabbed include: each copies it into its source before building.
  paletteH = pkgs.writeText "palette.h" (import ./palette.nix).c;
  withPalette =
    pkg:
    pkg.overrideAttrs (old: {
      postPatch = (old.postPatch or "") + "\ncp ${paletteH} palette.h\n";
    });

  # Redraws the status the moment the volume or the music changes
  # (scripts/follow.sh); pactl for PipeWire's PulseAudio events.
  slstatusFollow = pkgs.writeShellApplication {
    name = "slstatus-follow";
    runtimeInputs = with pkgs; [
      gnugrep
      playerctl
      procps
      pulseaudio
    ];
    text = builtins.readFile ./scripts/follow.sh;
  };
in
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

      # Key repeat as on the Mac: 583 ms before a held key repeats, then a
      # repeat every 83 ms (macOS's HIDInitialKeyRepeat and HIDKeyRepeat,
      # read from ioreg). The guest repeats keys itself, from the key down
      # UTM passes it, and X's own defaults are 660 ms and 25 a second.
      autoRepeatDelay = 583;
      autoRepeatInterval = 83;

      # dwm/config.h is the whole configuration: upstream's defaults with
      # Super as the modifier and the look (colours, font, borders, gaps).
      # The patches add what a config.h cannot: gaps, a colour scheme of
      # its own for the window title, restarting in place (which loads a new
      # dwm without closing any window or moving it off its desktop),
      # colours in the status text, the window's icon beside its title, the
      # bar's look (its height, inset status blocks, after chadwm's a colour
      # and an icon per desktop), tabs in monocle, a system tray, every
      # window in the bar with a terminal's directory, git branch and agent
      # as chips (published by dwm-chips, home.nix), an app's other windows
      # grouped there as one, an empty desktop starting its app, status
      # blocks a click opens a dropdown for (slstatus/config.h names them),
      # and the look of tmux's status line, its blocks joined by powerline
      # arrows. Its tags, window rules, per-tag keys and those apps come
      # from desktops.h, generated from the desktops shared with AeroSpace
      # (lib/desktops.nix).
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
              ./dwm/preserveonrestart.diff
              ./dwm/winicon.diff
              ./dwm/tab.diff
              ./dwm/systray.diff
              ./dwm/chadwmbar.diff
              ./dwm/chips.diff
              ./dwm/barlist.diff
              ./dwm/launch.diff
              ./dwm/statusclick.diff
              ./dwm/powerline.diff
              ./dwm/appgroups.diff
            ];
          }).overrideAttrs
            (old: {
              # nixpkgs' postPatch (the copy of config.h) ends without a
              # newline, so each command gets a line of its own
              postPatch = ''
                ${old.postPatch}
                cp ${pkgs.callPackage ./dwm/desktops.nix { }} desktops.h
                cp ${paletteH} palette.h
              '';
              # XRender and Imlib2, which scale and draw the window icons
              # (dwm/winicon.diff)
              buildInputs = old.buildInputs ++ [
                pkgs.libxrender
                pkgs.imlib2
              ];
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

          # FreeType's stem darkening, for every glyph its autohinter draws,
          # which light hinting uses for most fonts: JetBrains Mono, which
          # fontconfig autohints (fonts below), comes out as heavy as on the
          # Mac, and DejaVu or Liberation about 8% heavier than without it.
          # Everything started from this session inherits it.
          export FREETYPE_PROPERTIES="autofitter:no-stem-darkening=0"

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

          # The clipboard's history, for Mod+Shift+V (clipmenu in rofi): kept
          # in /run/user, so it ends with the session. Nothing copied while a
          # 1Password window has focus goes in. A password copied from
          # 1Password's browser extension would, since Chrome has the focus.
          CM_IGNORE_WINDOW=1Password CM_MAX_CLIPS=100 ${pkgs.clipmenu}/bin/clipmenud &

          # dwm's status text: the music, the volume, CPU, memory and disk
          # use, the date and the time in one grey block, refreshed every
          # second (slstatus/config.h), and at once when the volume or the
          # music changes.
          ${lib.getExe (withPalette (pkgs.slstatus.override { conf = ./slstatus/config.h; }))} &
          ${lib.getExe slstatusFollow} &
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

    # ── Scrolling ──────────────────────────────────────────────────
    # Natural scrolling for UTM's pointer, "Apple Inc. Virtual USB
    # Digitizer" (a mouse to udev), which carries the Mac's mouse and
    # trackpad alike. The Mac reverses its mouse wheel with Scroll
    # Reverser, which the guest never sees, so without this the wheel
    # scrolled backwards here.
    libinput.mouse.naturalScrolling = true;

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

    # Except JetBrains Mono, the desktop's font (dwm, dmenu, st, tabbed,
    # dunst and rofi ask for it at 15px, SemiBold), drawn the way the Mac's
    # Ghostty draws it with font-thicken: greyscale, lightly autohinted, and
    # thickened by FreeType's stem darkening (FREETYPE_PROPERTIES, set with
    # the X session above). Measured against a screenshot of Ghostty on the
    # Mac, the same line lays down the same amount of ink, 100%, where Hack
    # as rendered before came to 62%.
    fontconfig.localConf = ''
      <?xml version="1.0"?>
      <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
      <fontconfig>
        <match target="font">
          <test name="family"><string>JetBrainsMono Nerd Font</string></test>
          <edit name="antialias" mode="assign"><bool>true</bool></edit>
          <edit name="rgba" mode="assign"><const>none</const></edit>
          <edit name="hinting" mode="assign"><bool>true</bool></edit>
          <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>
          <edit name="autohint" mode="assign"><bool>true</bool></edit>
        </match>
      </fontconfig>
    '';
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
      # suckless terminal in the Mac's terminal font, JetBrains Mono SemiBold at
      # 15px (drawn as on the Mac: fonts above), and Ghostty's colours
      # (st/colors.diff), bold text included (st/bold-is-not-bright.diff)
      patches = (old.patches or [ ]) ++ [
        (pkgs.writeText "font.patch" ''
          diff --git a/config.def.h b/config.def.h
          --- a/config.def.h
          +++ b/config.def.h
          @@ -7,1 +7,1 @@
          -static char *font = "Liberation Mono:pixelsize=12:antialias=true:autohint=true";
          +static char *font = "JetBrainsMono Nerd Font:size=11.25:weight=semibold";
        '')
        ./st/colors.diff
        ./st/bold-is-not-bright.diff
      ];
      # libXcursor, for themed cursors (see Cursor above)
      postFixup = (old.postFixup or "") + ''
        patchelf --add-needed libXcursor.so.1 --add-rpath ${lib.getLib libxcursor}/lib $out/bin/st
      '';
    }))
    adwaita-icon-theme # the cursor theme (xdg.icons above)
    # DWM launcher; -h, which dwm passes, makes its line as tall as the bar
    (dmenu.override { patches = [ ./dmenu/lineheight.diff ]; })
    # The themed launcher, Mod+R (configs/rofi), with the calculator and the
    # emoji picker for Mod+equal and Mod+E (dwm/config.h)
    (rofi.override {
      plugins = [
        rofi-calc
        rofi-emoji
      ];
    })
    # Papirus's icons, for rofi's apps and dunst's notifications
    papirus-icon-theme
    # The dashboard, Mod+A (configs/eww); playerctl drives its music section
    eww
    playerctl
    # The clipboard's history, Mod+Shift+V; clipmenud starts with the session
    clipmenu
    # Tabs around st, Mod+Shift+T, in the desktop's colours
    (withPalette (tabbed.override { customConfig = builtins.readFile ./tabbed/config.h; }))
    # Started with the X session above; here for dunstctl (Mod+N and its
    # neighbours in dwm/config.h)
    dunst
    # notify-send, for scripts to post notifications through dunst
    libnotify
    # Google's own arm64 build (unfree, allowed above), so not in the
    # binary cache: a switch fetches the .deb from Google and repackages it.
    # dmenu finds it as google-chrome-stable.
    google-chrome
    # Slack, Spotify and Discord as their web apps, each in its own Chrome
    # app window. Their desktop apps wrap these same web UIs in a bundled
    # Chromium, but they publish that bundle for Linux only on x86_64 (Slack
    # an amd64 .deb, Spotify an amd64 snap, Discord an amd64 .deb and
    # tarball), so nixpkgs has none of them for aarch64-linux. Spotify's
    # player needs Widevine, which this Chrome ships.
    (writeShellScriptBin "slack" ''
      exec ${lib.getExe google-chrome} --app=https://app.slack.com/client "$@"
    '')
    (writeShellScriptBin "spotify" ''
      exec ${lib.getExe google-chrome} --app=https://open.spotify.com "$@"
    '')
    (writeShellScriptBin "discord" ''
      exec ${lib.getExe google-chrome} --app=https://discord.com/app "$@"
    '')
    # Signal has no web app. nixpkgs builds its desktop app for aarch64-linux
    # from source but the binary cache lacks that build, so a switch
    # compiles the app, its sticker creator and its SQLCipher module; the
    # rest, Electron and libsignal included, comes from the cache.
    signal-desktop
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
