{
  pkgs,
  lib,
  config,
  ...
}:
{
  home.homeDirectory = lib.mkForce "/home/${config.my.user.name}";

  home.packages = with pkgs; [
    xclip
    xsel
  ];

  home.file.".gitconfig.local".text = ''
    [gpg "ssh"]
    	program = ${pkgs.openssh}/bin/ssh-keygen

    [commit]
    	gpgsign = true
  '';
}
