{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # ── Core CLI & Shell ───────────────────────────────────────────────
    coreutils
    findutils
    binutils
    moreutils
    gnupg
    git
    gh
    git-filter-repo
    curl
    wget
    xh
    watch
    pv
    jq
    yq
    sops
    ripgrep
    sd
    fd
    fzf
    zoxide
    zsh-completions
    inetutils

    # ── Shell Experience ───────────────────────────────────────────────
    atuin
    vivid
    eza
    bat
    gum
    figlet
    toilet
    duf
    dust
    gping
    bandwhich
    procs
    btop
    htop
    chevron
    delta
    difftastic

    # ── Editors ────────────────────────────────────────────────────────
    neovim

    # ── Network & Security ─────────────────────────────────────────────
    _1password-cli
    nmap
    socat
    mtr
    iftop
    wireshark-cli
    sshuttle
    sslscan
    testssl
    ipmitool
    sshpass
    stable.samba
    doggo

    # ── AI ────────────────────────────────────────────────────────────
    claude-code
    codex
    beads

    # ── Misc CLI ───────────────────────────────────────────────────────
    just
    nvd
    statix
    tmux
    dolt
    tree
    # direnv + nix-direnv installed via programs.direnv in modules/home/shell.nix
    # so home-manager wires the share/nix-direnv path correctly.
    rclone
    restic
    pstree
    dos2unix
    hexyl
    tealdeer
    p7zip
    qpdf
    xz
    mmv-go
    glow
    asciinema
    vhs
    transcrypt
    recs
  ];
}
