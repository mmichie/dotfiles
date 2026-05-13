{ lib, mkLink, ... }:
{
  xdg.configFile = {
    "ghostty".source = mkLink "ghostty";
    "tmux".source = mkLink "tmux";
    "dosbox-x".source = mkLink "dosbox-x";
  };

  home.file = {
    ".wezterm.lua".source = mkLink "wezterm/.wezterm.lua";
    ".ssh/config".source = mkLink "ssh/config";

    # Public key stub — OpenSSH 10.2+ requires a .pub file on disk to offer
    # agent-managed keys (e.g. from 1Password) during authentication.
    ".ssh/id_ed25519.pub".text =
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFu6EGwcAtua7e2eBu3KNTGdBKP+0UOim1M0cvZgzF6U mmichie@gmail.com\n";
  };

  # authorized_keys must be a real user-owned file. home.file writes via a
  # /nix/store symlink whose target is root-owned, which sshd's StrictModes
  # rejects on macOS. Write it during activation instead.
  home.activation.writeAuthorizedKeys = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        if [ -L "$HOME/.ssh/authorized_keys" ]; then
          rm "$HOME/.ssh/authorized_keys"
        fi
        tmp="$HOME/.ssh/.authorized_keys.tmp.$$"
        cat > "$tmp" <<'KEYS'
    ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFu6EGwcAtua7e2eBu3KNTGdBKP+0UOim1M0cvZgzF6U mmichie@gmail.com
    KEYS
        chmod 600 "$tmp"
        mv "$tmp" "$HOME/.ssh/authorized_keys"
  '';
}
