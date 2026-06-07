{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # ── Google Workspace admin ─────────────────────────────────────────
    # GAM7 (GAM-team/GAM). Reads config + creds from ~/.gam; client_secrets
    # and oauth2service come from sops (see modules/home/secrets.nix),
    # oauth2.txt is machine-local runtime state (carried by secrets-backup).
    gam

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
    gnumake
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
