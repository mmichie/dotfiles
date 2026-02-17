{ pkgs, config, ... }:

{
  home.username = "mim";
  home.homeDirectory = "/home/mim";
  home.stateVersion = "24.11";

  # Linux-specific packages
  home.packages = with pkgs; [
    xclip
    xsel
  ];

  # ── SSH: override 1Password IdentityAgent ──────────────────────
  # The shared SSH config sets IdentityAgent to the macOS 1Password socket.
  # On Linux, use the standard SSH agent so agent forwarding works.
  home.file.".ssh/config.local".text = ''
    Host *
    	IdentityAgent SSH_AUTH_SOCK
    	IdentitiesOnly no
  '';
}
