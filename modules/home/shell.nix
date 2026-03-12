{ config, ... }:

let
  dotfiles = "${config.home.homeDirectory}/src/dotfiles/configs";
in
{
  # zsh config — managed externally, symlinked in
  home.file.".zshrc".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/zsh/.zshrc";
  home.file.".zsh".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/zsh/.zsh";

  # Direnv config (nix-direnv integration)
  xdg.configFile."direnv".source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/direnv";

  # Starship prompt config
  xdg.configFile."starship.toml".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/starship/starship.toml";
}
