# Shared configuration for macOS workstations.
# Per-host configs (hosts/<name>/configuration.nix) should import this and
# only set networking.hostName (plus any host-specific overrides).
{ pkgs, ... }:

{
  imports = [
    ./defaults.nix
    ./homebrew.nix
  ];

  # Determinate Systems manages the Nix daemon — disable nix-darwin's management
  nix.enable = false;

  # Backstop GC for idle stretches — `just switch` already GCs to 3d on every
  # apply, so this only matters when the machine goes days without a switch.
  # Runs weekly (Sunday 2 AM). Uses launchd directly because nix.gc requires
  # nix.enable, which is disabled (Determinate Systems manages the daemon).
  launchd.daemons.nix-gc = {
    command = "/nix/var/nix/profiles/default/bin/nix-collect-garbage --delete-older-than 3d";
    serviceConfig = {
      RunAtLoad = false;
      StartCalendarInterval = [
        {
          Weekday = 0;
          Hour = 2;
          Minute = 0;
        }
      ];
    };
  };

  nixpkgs.config.allowUnfree = true;
  nixpkgs.hostPlatform = "aarch64-darwin";

  environment.systemPackages = with pkgs; [
    vim
    git
  ];

  # Touch ID for sudo (reattach fixes it inside tmux)
  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true;
  };

  programs.zsh = {
    enable = true;
    # No compinit in the generated /etc/zshrc: it runs a FULL bare compinit
    # (security audit + dump check on ~/.zcompdump) before ~/.zshrc's
    # fingerprinted `compinit -C` fast path even gets a chance — measured at
    # ~36ms per shell.
    enableGlobalCompInit = false;
    # Separate option, NOT covered by enableGlobalCompInit (the generated
    # /etc/zshrc kept bashcompinit after compinit was removed): nothing in
    # configs/zsh uses bash-style completions.
    enableBashCompletion = false;
    # The default scans every fpath dir for prompt_*_setup via promptinit
    # and renders the suse theme (~8ms per shell) — thrown away one module
    # later when lib/60-prompt.zsh installs the chevron prompt.
    promptInit = "";
  };

  fonts.packages = with pkgs; [
    nerd-fonts.iosevka
  ];

  system = {
    primaryUser = "mim";

    # Copy nix apps to /Applications so Spotlight can index them
    # (symlinks into /nix/store are invisible to Spotlight)
    activationScripts.applications.text =
      let
        apps = pkgs.buildEnv {
          name = "system-apps";
          paths = with pkgs; [ wezterm ];
          pathsToLink = [ "/Applications" ];
        };
      in
      pkgs.lib.mkForce ''
        echo "setting up /Applications/Nix Apps..." >&2
        app_dir="/Applications/Nix Apps"
        rm -rf "$app_dir"
        mkdir -p "$app_dir"
        for app in ${apps}/Applications/*; do
          cp -rL "$app" "$app_dir/$(basename "$app")"
        done
      '';

    # Spotlight recurrently sheds an arbitrary subset of /Applications from
    # its index, so cask apps vanish from cmd-space search. Heal after every
    # activation and print the drift count first: a switch is this machine's
    # biggest churn event (brew upgrade rewrites bundles while nix GC deletes
    # store paths), so a recurring nonzero count here is evidence that
    # switches trigger the loss. mdls prints `kMDItemFSName = (null)` for a
    # bundle absent from the store; a quoted name means it is indexed.
    activationScripts.postActivation.text = ''
      missing=0
      for app in /Applications/*.app; do
        [ -e "$app" ] || continue
        if ! mdls -name kMDItemFSName "$app" 2>/dev/null | grep -q '"'; then
          missing=$((missing + 1))
          mdimport "$app" 2>/dev/null || true
        fi
      done
      if [ "$missing" -eq 0 ]; then
        echo "spotlight: /Applications fully indexed"
      else
        echo "spotlight: reimported $missing app(s) missing from the index"
      fi
    '';

    stateVersion = 6;
  };
}
