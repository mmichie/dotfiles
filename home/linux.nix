_: {
  # Standalone Linux: use the ambient SSH agent (no 1Password forwarding)
  home.file.".ssh/config.local".text = ''
    Host *
    	IdentityAgent SSH_AUTH_SOCK
    	IdentitiesOnly no
  '';
}
