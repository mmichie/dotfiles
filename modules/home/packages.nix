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
    duf
    dust
    gping
    bandwhich
    procs
    btop
    htop
    starship
    delta
    difftastic

    # ── Editors ────────────────────────────────────────────────────────
    neovim

    # ── Terminal Multiplexer ───────────────────────────────────────────
    tmux

    # ── Development — Go ───────────────────────────────────────────────
    go
    gopls
    golangci-lint

    # ── Development — Rust ─────────────────────────────────────────────
    cargo
    rustc
    rustfmt
    clippy

    # ── Development — Python ───────────────────────────────────────────
    pipx
    uv
    ruff
    pyright

    # ── Development — Node ─────────────────────────────────────────────
    nodejs
    nodePackages.prettier

    # ── Development — C/C++ ────────────────────────────────────────────
    cmake
    clang-tools # includes clang-format

    # ── Development — Other ────────────────────────────────────────────
    shellcheck
    pre-commit
    lefthook
    tokei
    hyperfine
    just
    watchexec

    # ── Infrastructure & Cloud ─────────────────────────────────────────
    google-cloud-sdk
    awscli2
    kubectl
    kubernetes-helm
    stern
    kind
    minikube
    docker-compose
    opentofu
    ansible

    # ── Network & Security ─────────────────────────────────────────────
    nmap
    socat
    mtr
    iftop
    wireshark-cli
    sshuttle

    # ── Media & Documents ──────────────────────────────────────────────
    ffmpeg
    imagemagick
    pandoc
    yt-dlp

    # ── AI ────────────────────────────────────────────────────────────
    claude-code

    # ── Misc CLI ───────────────────────────────────────────────────────
    rclone
    restic
    pstree
    dos2unix
    hexyl
    tealdeer
    p7zip
    xz
    mmv-go
    glow
    asciinema
    vhs
    transcrypt
  ];
}
