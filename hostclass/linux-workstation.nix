{ pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      keybase
      xclip
      xsel
    ];

    file.".gitconfig.local".text = ''
      [gpg "ssh"]
      	program = ${pkgs.openssh}/bin/ssh-keygen

      [commit]
      	gpgsign = true
    '';

    # Use the ambient agent: $SSH_AUTH_SOCK from the user's session on standalone
    # Linux, or the forwarded macOS host agent inside the VMware Fusion VM.
    file.".ssh/config.local".text = ''
      Host *
      	IdentityAgent SSH_AUTH_SOCK
      	IdentitiesOnly no
    '';
  };
}
