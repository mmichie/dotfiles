{
  pkgs,
  config,
  lib,
  ...
}:

let
  dotfiles = "${config.home.homeDirectory}/src/dotfiles/configs";
in
{
  home.homeDirectory = lib.mkForce "/home/mim";

  # NixOS VM-specific packages
  home.packages = with pkgs; [
    xclip
    xsel
  ];

  # ── Git: override 1Password SSH signing (not available in VM) ──
  home.file.".gitconfig.local".text = ''
    [gpg "ssh"]
    	program = /run/current-system/sw/bin/ssh-keygen

    [commit]
    	gpgsign = false
  '';

  # ── SSH: override 1Password IdentityAgent ──────────────────────
  home.file.".ssh/config.local".text = ''
    # VM override — use standard SSH agent instead of 1Password
    Host *
    	IdentityAgent ~/.ssh/agent.sock
    	IdentitiesOnly no
  '';
}
