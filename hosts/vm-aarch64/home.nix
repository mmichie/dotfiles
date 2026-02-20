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

  # ── Git: use ssh-keygen for signing (works with forwarded 1Password agent) ──
  home.file.".gitconfig.local".text = ''
    [gpg "ssh"]
    	program = /run/current-system/sw/bin/ssh-keygen

    [commit]
    	gpgsign = true
  '';

  # ── SSH: use forwarded agent from 1Password ────────────────────
  home.file.".ssh/config.local".text = ''
    # VM override — use forwarded 1Password SSH agent via SSH_AUTH_SOCK
    Host *
    	IdentityAgent $SSH_AUTH_SOCK
    	IdentitiesOnly no
  '';
}
