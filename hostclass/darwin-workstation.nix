{
  pkgs,
  mkLink,
  ...
}:
{
  home.packages = with pkgs; [
    pinentry_mac
    terminal-notifier
    # mlx-lm is NOT here: nixpkgs builds mlx with -DMLX_BUILD_METAL=FALSE, so
    # its mlx_lm runs entirely on the CPU. See modules/darwin/homebrew.nix.
  ];

  xdg.configFile."aerospace".source = mkLink "aerospace";
  xdg.configFile."karabiner".source = mkLink "karabiner";

  # Homebrew tap trust is declared in modules/darwin/homebrew.nix (via
  # `trusted: true` Brewfile entries), NOT here: trust.json must be a real file
  # Homebrew can write, and a home-manager symlink into the read-only Nix store
  # makes `brew bundle --force-cleanup` fail with "insecure trust store".
}
