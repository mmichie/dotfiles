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

  # ── Time & locale ──────────────────────────────────────────────
  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_US.UTF-8";

  # ── VMware guest tools ─────────────────────────────────────────
  virtualisation.vmware.guest.enable = true;

  # ── X11 + DWM ──────────────────────────────────────────────────
  services.xserver = {
    enable = true;
    xkb.layout = "us";

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
          +static char *font = "Hack Nerd Font:pixelsize=16:antialias=true:autohint=true";
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
  };

  users.users.root.initialPassword = "nixos";

  programs.zsh.enable = true;

  # ── Security ───────────────────────────────────────────────────
  security.sudo.wheelNeedsPassword = false; # Single-user dev VM

  # ── State version ──────────────────────────────────────────────
  system.stateVersion = "25.05";
}
