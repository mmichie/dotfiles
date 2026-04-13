{ config, ... }:
{
  xdg.configFile."ghostty".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesPath}/ghostty";
  home.file.".wezterm.lua".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesPath}/wezterm/.wezterm.lua";
  xdg.configFile."tmux".source = config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesPath}/tmux";
  home.file.".ssh/config".source =
    config.lib.file.mkOutOfStoreSymlink "${config.my.dotfilesPath}/ssh/config";

  # Public key stub — OpenSSH 10.2+ requires a .pub file on disk to offer
  # agent-managed keys (e.g. from 1Password) during authentication.
  home.file.".ssh/id_ed25519.pub".text =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFu6EGwcAtua7e2eBu3KNTGdBKP+0UOim1M0cvZgzF6U mmichie@gmail.com\n";

  # Authorized keys — managed here so fresh installs (macOS + Linux) are consistent.
  # NixOS targets declare this via users.users.mim.openssh.authorizedKeys.keys instead.
  home.file.".ssh/authorized_keys".text =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFu6EGwcAtua7e2eBu3KNTGdBKP+0UOim1M0cvZgzF6U mmichie@gmail.com\n";
}
