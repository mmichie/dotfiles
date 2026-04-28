{
  imports = [ ../../modules/darwin/workstation-base.nix ];
  networking.hostName = "tensor9-mbp";

  # Loopback alias management for tensor9 local testing.
  security.sudo.extraConfig = ''
    mim ALL=(ALL) NOPASSWD: /sbin/ifconfig lo0 alias *, /sbin/ifconfig lo0 inet * delete
  '';
}
