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

      windowManager.dwm = {
        enable = true;
        package = pkgs.dwm.overrideAttrs (old: {
          patches = (old.patches or [ ]) ++ [
            # Use Super (Windows) key instead of Alt as modifier
            # UTM passes the Mac's Command key through as Super, so this
            # lets you use the key next to Space as the DWM mod key
            (pkgs.writeText "modkey.patch" ''
              diff --git a/config.def.h b/config.def.h
              --- a/config.def.h
              +++ b/config.def.h
              @@ -48,1 +48,1 @@
              -#define MODKEY Mod1Mask
              +#define MODKEY Mod4Mask
            '')
          ];
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

          while true; do
            xsetroot -name "$(date '+%a %d %b %R') | $(cat /proc/loadavg | cut -d' ' -f1-3)"
            sleep 10
          done &
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

  # ── System packages ────────────────────────────────────────────
  environment.systemPackages = with pkgs; [
    vim
    git
    wget
    curl
    (st.overrideAttrs (old: {
      # suckless terminal with Nerd Font
      patches = (old.patches or [ ]) ++ [
        (pkgs.writeText "font.patch" ''
          diff --git a/config.def.h b/config.def.h
          --- a/config.def.h
          +++ b/config.def.h
          @@ -7,1 +7,1 @@
          -static char *font = "Liberation Mono:pixelsize=12:antialias=true:autohint=true";
          +static char *font = "Hack Nerd Font:size=11:antialias=true:autohint=false";
        '')
      ];
    }))
    dmenu # DWM launcher
    xclip
    xsel
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

  programs.zsh = {
    enable = true;
    # Same rationale as darwin: ~/.zshrc runs its own fingerprinted compinit;
    # the global one in /etc/zshrc would be a second, slower compinit.
    enableGlobalCompInit = false;
    # And as on darwin: no bashcompinit (nothing uses bash-style completions),
    # no global prompt theme (lib/60-prompt.zsh replaces it anyway).
    enableBashCompletion = false;
    promptInit = "";
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
