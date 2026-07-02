{ pkgs, ... }:
{
  home = {
    packages = with pkgs; [
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
      # zsh agent handling consumes this stable link
      # (configs/zsh/.zsh/lib/80-ssh.zsh). sshd runs ~/.ssh/rc once per
      # connection with the fresh SSH_AUTH_SOCK in the environment. (Having
      # ~/.ssh/rc disables the default X11 cookie handling, which this headless
      # box does not use.)
      ".ssh/rc".text = ''
        if [ -n "$SSH_AUTH_SOCK" ] && [ "$SSH_AUTH_SOCK" != "$HOME/.ssh/ssh_auth_sock" ]; then
          ln -snf "$SSH_AUTH_SOCK" "$HOME/.ssh/ssh_auth_sock"
        fi
      '';
    };
  };
}
