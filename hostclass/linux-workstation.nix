{ pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      xclip
      xsel
    ];

    file.".gitconfig.local".text = ''
      [gpg "ssh"]
      	program = ${pkgs.openssh}/bin/ssh-keygen

      [commit]
      	gpgsign = true
    '';
  };
}
