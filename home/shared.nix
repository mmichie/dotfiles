{
  pkgs,
  lib,
  config,
  mkLink,
  ...
}:
let
  homePrefix = if pkgs.stdenv.isDarwin then "/Users" else "/home";
in
{
  home = {
    username = config.my.user.name;
    # mkForce overrides home-manager's nixos/darwin integration, which defaults
    # homeDirectory from users.users.<name>.home (null when not configured).
    homeDirectory = lib.mkForce "${homePrefix}/${config.my.user.name}";
    inherit (config.my.user) stateVersion;
    enableNixpkgsReleaseCheck = false;
  };

  programs.home-manager.enable = true;

  # Session variables — centralized here rather than scattered across shell configs
  home.sessionVariables = {
    DIRENV_LOG_FORMAT = ""; # Silence direnv loading noise
  };

  # ~/bin — scripts and platform binaries (uses dotfilesRoot, not dotfilesPath)
  home.file."bin".source = config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesRoot}/bin/bin";

  # System-level dotfiles
  home.file.".inputrc".source = mkLink "system/.inputrc";
  home.file.".actrc".source = mkLink "system/.actrc";
  home.file.".ideavimrc".source = mkLink "system/.ideavimrc";
  home.file.".tmux-cht-command".source = mkLink "system/.tmux-cht-command";
  home.file.".tmux-cht-languages".source = mkLink "system/.tmux-cht-languages";

  # TUI monitors — file-level so runtime state (btop.log, themes) stays native
  xdg.configFile."btop/btop.conf".source = mkLink "btop/btop.conf";
  xdg.configFile."htop/htoprc".source = mkLink "htop/htoprc";

  # Claude Code settings
  home.file.".claude/settings.json".source = mkLink "claude/settings.json";
  home.file.".claude/CLAUDE.md".source = mkLink "claude/CLAUDE.md";
  home.file.".claude/statusline-command.sh".source = mkLink "claude/statusline-command.sh";
  home.file.".claude/commands/work.md".source = mkLink "claude/commands/work.md";

  # Upstream agents vendored from davila7/claude-code-templates — refresh via
  # `just claude-update`.
  home.file.".claude/agents/development-tools/code-reviewer.md".source =
    mkLink "claude/agents/development-tools/code-reviewer.md";
  home.file.".claude/agents/development-tools/refactoring-specialist.md".source =
    mkLink "claude/agents/development-tools/refactoring-specialist.md";
}
