{ pkgs, ... }:
{
  home = {
    packages = with pkgs; [
      # Linux-only on purpose. On macOS GNU binutils' unprefixed ar, nm, strip
      # and ranlib shadow Apple's, and Apple's ld rejects static archives built
      # with GNU ar ("64-bit mach-o not 8-byte aligned"), which breaks native
      # builds outside nix.
      binutils
      keybase
      xclip
      xsel
    ];

    file = {
      ".gitconfig.local".text = ''
        [gpg "ssh"]
        	program = ${pkgs.openssh}/bin/ssh-keygen

        [commit]
        	gpgsign = true
      '';

      # Use the ambient agent: $SSH_AUTH_SOCK from the user's session on
      # standalone Linux, or the forwarded macOS host agent inside the VMware
      # Fusion VM.
      ".ssh/config.local".text = ''
        Host *
        	IdentityAgent SSH_AUTH_SOCK
        	IdentitiesOnly no
      '';

      # Repoint a stable path at each login's forwarded agent socket. Forwarded
      # sockets are per-login and ephemeral, so a tmux pane that outlives its SSH
      # login is otherwise left pointing at a dead socket after re-attach; the
      # zsh agent handling consumes this stable link and repoints it itself
      # (configs/zsh/.zsh/lib/80-ssh.zsh), because only sshd runs ~/.ssh/rc:
      # Tailscale SSH spawns login(1) directly. rc still covers sshd sessions
      # that start no shell; sshd runs it once per connection with the fresh
      # SSH_AUTH_SOCK in the environment. (Having ~/.ssh/rc disables the
      # default X11 cookie handling, which this headless box does not use.)
      ".ssh/rc".text = ''
        if [ -n "$SSH_AUTH_SOCK" ] && [ "$SSH_AUTH_SOCK" != "$HOME/.ssh/ssh_auth_sock" ]; then
          ln -snf "$SSH_AUTH_SOCK" "$HOME/.ssh/ssh_auth_sock"
        fi
      '';
    };
  };
}
