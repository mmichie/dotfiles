{
  lib,
  pkgs,
  config,
  mkLink,
  ...
}:
{
  xdg.configFile = {
    "ghostty".source = mkLink "ghostty";
    "tmux".source = mkLink "tmux";
    "dosbox-x".source = mkLink "dosbox-x";
  };

  home = {
    file = {
      ".wezterm.lua".source = mkLink "wezterm/.wezterm.lua";
      ".ssh/config".source = mkLink "ssh/config";

      # Public key stub — OpenSSH 10.2+ requires a .pub file on disk to offer
      # agent-managed keys (e.g. from 1Password) during authentication.
      ".ssh/id_ed25519.pub".text =
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFu6EGwcAtua7e2eBu3KNTGdBKP+0UOim1M0cvZgzF6U mmichie@gmail.com\n";
    };

    activation = {
      # authorized_keys must be a real user-owned file. home.file writes via a
      # /nix/store symlink whose target is root-owned, which sshd's StrictModes
      # rejects on macOS. Write it during activation instead. Using printf (not
      # heredoc) so nix-fmt's reindentation doesn't break the embedded content.
      writeAuthorizedKeys = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        if [ -L "$HOME/.ssh/authorized_keys" ]; then
          rm "$HOME/.ssh/authorized_keys"
        fi
        tmp="$HOME/.ssh/.authorized_keys.tmp.$$"
        printf '%s\n' \
          'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFu6EGwcAtua7e2eBu3KNTGdBKP+0UOim1M0cvZgzF6U mmichie@gmail.com' \
          > "$tmp"
        chmod 600 "$tmp"
        mv "$tmp" "$HOME/.ssh/authorized_keys"
      '';

      # The tmux config sources vendored plugins (dwm.tmux, tpm, tmux-resurrect,
      # tmux-yank, tmux-thumbs) from configs/tmux/plugins/, which are git
      # submodules. A plain `git clone` of this repo leaves them uninitialized,
      # so tmux's source-file silently fails: the dwm master/stack bindings and
      # pane-exited hook never load (and the tmux suite's dwm assertions fail on
      # a freshly cloned host). Initialize them on every switch — idempotent, a
      # no-op once present and fetching only when a submodule is missing — so a
      # fresh machine gets a working tmux without anyone having to remember
      # `git clone --recurse-submodules`.
      tmuxPluginSubmodules = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        root="${config.my.dotfilesRoot}"
        if ${pkgs.git}/bin/git -C "$root" rev-parse --git-dir > /dev/null 2>&1; then
          ${pkgs.git}/bin/git -C "$root" submodule update --init \
            || echo "warning: could not initialize tmux plugin submodules in $root (offline?)" >&2
        fi
      '';
    };
  };
}
