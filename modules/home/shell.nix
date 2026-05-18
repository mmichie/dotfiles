{ mkLink, ... }:
{
  home.file = {
    ".zshenv".source = mkLink "zsh/.zshenv";
    ".zprofile".source = mkLink "zsh/.zprofile";
    ".zshrc".source = mkLink "zsh/.zshrc";
    ".zsh".source = mkLink "zsh/.zsh";
  };

  # direnv + nix-direnv via home-manager so the right direnvrc and the
  # nix-direnv share files are wired up under ~/.config/direnv. The zsh hook
  # is still installed manually in configs/zsh/.zsh/lib/50-integrations.zsh.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    config.whitelist.prefix = [ "~/src" ];
  };
}
