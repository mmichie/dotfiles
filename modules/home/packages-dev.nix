{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # ── Terminals ─────────────────────────────────────────────────────
    wezterm

    # ── Development — Java ─────────────────────────────────────────────
    openjdk17

    # ── Development — Go ───────────────────────────────────────────────
    go
    gopls
    gofumpt
    delve
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
    prettier
    pnpm

    # ── Development — C/C++ ────────────────────────────────────────────
    cmake
    clang-tools

    # ── Development — Other ────────────────────────────────────────────
    shellcheck
    shfmt
    pre-commit
    lefthook
    tokei
    hyperfine
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
    (python3.withPackages (ps: [
      ps.ansible-core
      ps.boto3
    ]))
    ssm-session-manager-plugin

    # ── Media & Documents ──────────────────────────────────────────────
    ansilove
    chafa
    ffmpeg
    imagemagick
    pandoc
    poppler-utils
    texliveSmall
    stable.yt-dlp

    # ── Fonts ─────────────────────────────────────────────────────────
    nerd-fonts.departure-mono
    nerd-fonts.fira-code
    nerd-fonts.hack
    nerd-fonts.iosevka
    nerd-fonts.iosevka-term
    nerd-fonts.jetbrains-mono
    nerd-fonts.zed-mono
  ];
}
