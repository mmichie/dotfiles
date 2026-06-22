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

  # Homebrew tap trust is declared in modules/darwin/homebrew.nix (via
  # `trusted: true` Brewfile entries), NOT here: trust.json must be a real file
  # Homebrew can write, and a home-manager symlink into the read-only Nix store
  # makes `brew bundle --force-cleanup` fail with "insecure trust store".
}
