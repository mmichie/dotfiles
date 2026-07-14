{ pkgs, config, ... }:
{
  home.packages = with pkgs; [
    # ── Google Workspace admin ─────────────────────────────────────────
    # GAM7 (GAM-team/GAM). The gam() wrapper (configs/zsh/.zsh/functions/gam)
    # materializes client_secrets.json + oauth2service.json from 1Password on
    # first use; oauth2.txt + gam.cfg are machine-local (carried by
    # secrets-backup). Nothing GAM-secret lives in this repo.
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
    # CLI needed by nvim-treesitter (main branch) to build grammars on
    # :TSInstall / :TSUpdate
    tree-sitter
    pre-commit
    lefthook
    tokei
    hyperfine
    watchexec

    # ── Infrastructure & Cloud ─────────────────────────────────────────
    google-cloud-sdk
    awscli2
    azure-cli
    kubectl
    kubernetes-helm
    stern
    kind
    minikube
    docker-compose
    # IaC CLI: OpenTofu by default; Terraform on hosts whose project CI/state is
    # HashiCorp Terraform (selected per host via my.iacTool — e.g. mim-moab).
    (if config.my.iacTool == "terraform" then terraform else opentofu)
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
