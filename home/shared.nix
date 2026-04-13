{ pkgs, config, ... }:
let
  homePrefix = if pkgs.stdenv.isDarwin then "/Users" else "/home";
in
{
  home = {
    username = config.my.user.name;
    homeDirectory = "${homePrefix}/${config.my.user.name}";
    inherit (config.my.user) stateVersion;
    enableNixpkgsReleaseCheck = false;
  };

  programs.home-manager.enable = true;

  home.packages = [ pkgs.plx ];

  # ~/bin — scripts and platform binaries
  home.file."bin".source = config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesRoot}/bin/bin";

  # System-level dotfiles
  home.file.".inputrc".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesPath}/system/.inputrc";
  home.file.".dircolors".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesPath}/system/.dircolors";
  home.file.".tmux-cht-command".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesPath}/system/.tmux-cht-command";
  home.file.".tmux-cht-languages".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesPath}/system/.tmux-cht-languages";

  # Claude Code settings
  home.file.".claude/settings.json".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesPath}/claude/settings.json";

  # Clima config
  xdg.configFile."clima".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesPath}/system/clima";
  xdg.configFile."location".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesPath}/system/location";
}
