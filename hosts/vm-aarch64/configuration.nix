# NixOS VM — DWM tiling WM on VMware Fusion (Apple Silicon)
{
  pkgs,
  lib,
  self,
  ...
}:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # ── Nix settings ───────────────────────────────────────────────
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      "mim"
    ];
  };

  nixpkgs.config.allowUnfree = true;

  # ── Networking ─────────────────────────────────────────────────
  networking.hostName = "vm-aarch64";
  networking.networkmanager.enable = true;
  networking.nameservers = [
    "8.8.8.8"
    "8.8.4.4"
  ];
  networking.networkmanager.dns = "none"; # Don't let NM overwrite resolv.conf

  # ── Time & locale ──────────────────────────────────────────────
  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";

  # ── VMware guest tools ─────────────────────────────────────────
  virtualisation.vmware.guest.enable = true;
  virtualisation.vmware.guest.headless = false; # Include X11/GTK guest tools (auto-resize)

  environment.etc."vmware-tools/tools.conf".text = ''
    [vmblock]
    fuseMountPoint = /run/vmblock-fuse
  '';

  # ── Graphics (VMware 3D acceleration + Mesa OpenGL) ────────────
  hardware.graphics.enable = true;

  # ── X11 + DWM ──────────────────────────────────────────────────
  services.xserver = {
    enable = true;
    xkb.layout = "us";
    dpi = 96; # Native resolution (no HiDPI scaling)

    windowManager.dwm.enable = true;

    # Auto-login — single-user VM, skip the login screen
    displayManager.lightdm.enable = true;
  };

  services.displayManager = {
    defaultSession = "none+dwm";
    autoLogin = {
      enable = true;
      user = "mim";
    };
  };

  # DWM status bar via xsetroot (shows date/time/load)
  # Override with slstatus or your own script later
  services.xserver.displayManager.sessionCommands = ''
    # HiDPI settings for Retina display
    xrdb -merge <<XEOF
    Xft.dpi: 96
    Xft.autohint: 0
    Xft.lcdfilter: lcddefault
    Xft.hintstyle: hintfull
    Xft.hinting: 1
    Xft.antialias: 1
    Xft.rgba: rgb
    XEOF

    # Set ultrawide resolution (Acer X34 3440x1440)
    xrandr --newmode "3440x1440_60" 319.75 3440 3680 4048 4656 1440 1443 1453 1493 -hsync +vsync 2>/dev/null
    xrandr --addmode Virtual-1 3440x1440_60 2>/dev/null
    xrandr --output Virtual-1 --mode 3440x1440_60 2>/dev/null

    # Auto-resize VM display (set locale first to avoid GTK crash)
    export LC_ALL=C
    /run/wrappers/bin/vmware-user-suid-wrapper &

    while true; do
      xsetroot -name "$(date '+%a %d %b %R') | $(cat /proc/loadavg | cut -d' ' -f1-3)"
      sleep 10
    done &
  '';

  # ── Audio ──────────────────────────────────────────────────────
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  # ── Fonts ──────────────────────────────────────────────────────
  fonts.packages = with pkgs; [
    nerd-fonts.hack
    nerd-fonts.iosevka
    nerd-fonts.jetbrains-mono
    dejavu_fonts
    liberation_ttf
  ];

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
  users.users.mim = {
    isNormalUser = true;
    initialPassword = "nixos";
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

  users.users.root.initialPassword = "nixos";

  programs.zsh.enable = true;

  # ── SSH ─────────────────────────────────────────────────────────
  services.openssh.enable = true;

  # ── Security ───────────────────────────────────────────────────
  security.sudo.wheelNeedsPassword = false; # Single-user dev VM

  # ── State version ──────────────────────────────────────────────
  system.stateVersion = "25.05";
}
