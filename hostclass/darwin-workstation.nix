{
  pkgs,
  mkLink,
  ...
}:
{
  home.packages = with pkgs; [
    pinentry_mac
    terminal-notifier
  ];

  xdg.configFile."aerospace".source = mkLink "aerospace";
  xdg.configFile."karabiner".source = mkLink "karabiner";

  # Trust our third-party Homebrew taps for `brew bundle`. nix-darwin runs the
  # bundle via `sudo --preserve-env=PATH`, which strips XDG_CONFIG_HOME, so
  # Homebrew reads trust from ~/.homebrew/trust.json — NOT the XDG path
  # (~/.config/homebrew/trust.json) that interactive `brew trust` writes to.
  # Managing it here keeps switches reproducible without a manual `brew trust`.
  # Keep these in sync with the tap-qualified entries in
  # modules/darwin/homebrew.nix.
  # Note: on a fresh machine the first switch still fails the bundle (the
  # bundle runs before home-manager writes this file); a second switch, or a
  # one-time `env -u XDG_CONFIG_HOME brew trust --formula/--cask <item>`,
  # bootstraps it.
  home.file.".homebrew/trust.json".text = builtins.toJSON {
    trustedformulae = [ "tensor9ine/tensor9/tensor9" ];
    trustedcasks = [ "nikitabobko/tap/aerospace" ];
  };
}
