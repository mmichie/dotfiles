{ pkgs, ... }:

let
  beads = (pkgs.buildGoModule.override { go = pkgs.go_1_26; }) rec {
    pname = "beads";
    version = "0.55.4";
    src = pkgs.fetchFromGitHub {
      owner = "steveyegge";
      repo = "beads";
      rev = "v${version}";
      hash = "sha256-HTcmGKn2NNoBEg5yRsnVIATNdte5Xw8E86D09e1X5nk=";
    };
    vendorHash = "sha256-cMvxGJBMUszIbWwBNmWe+ws4m3mfyEZgapxVYNYc5c4=";
    subPackages = [ "cmd/bd" ];
    doCheck = false;
    env.CGO_ENABLED = "1";
    buildInputs = [ pkgs.icu ];
    nativeBuildInputs = [
      pkgs.git
      pkgs.pkg-config
    ];
    meta = {
      description = "Distributed issue tracker for AI-supervised workflows";
      mainProgram = "bd";
    };
  };
in
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
    starship
    delta
    difftastic

    # ── Editors ────────────────────────────────────────────────────────
    neovim

    # ── Terminals ─────────────────────────────────────────────────────
    wezterm
    tmux

    # ── Development — Java ─────────────────────────────────────────────
    openjdk17

    # ── Development — Go ───────────────────────────────────────────────
    go
    gopls
    golangci-lint

    # ── Development — Rust ─────────────────────────────────────────────
    cargo
    rustc
    rustfmt
    clippy
    rust-analyzer

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
    keybase
    nmap
    socat
    mtr
    iftop
    wireshark-cli
    sshuttle
    sslscan
    ipmitool
    sshpass
    stable.samba
    doggo

    # ── Media & Documents ──────────────────────────────────────────────
    ffmpeg
    imagemagick
    pandoc
    texliveSmall
    yt-dlp

    # ── AI ────────────────────────────────────────────────────────────
    claude-code
    beads

    # ── Fonts ────────────────────────────────────────────────────────────
    nerd-fonts.hack

    # ── Misc CLI ───────────────────────────────────────────────────────
    tree
    direnv
    nix-direnv
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
