_: {
  # VM-specific: use the forwarded 1Password SSH agent from the macOS host
  home.file.".ssh/config.local".text = ''
    Host *
    	IdentityAgent SSH_AUTH_SOCK
    	IdentitiesOnly no
  '';
}
