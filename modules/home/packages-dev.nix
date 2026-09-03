{
  pkgs,
  lib,
  config,
  ...
}:
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
    gotools # goimports, used synchronously by nvim's BufWritePre formatter
    delve
    golangci-lint

    # Mutation testing: generate mutants from the AST, run the covering tests
    # against each, report the SURVIVORS — changes to the code no test noticed.
    # A green suite says the tests pass; this says whether they would notice if
    # the code were wrong. Not in nixpkgs (see pkgs/gremlins).
    gremlins

    # CodeQL: global dataflow and taint queries over the whole codebase. The
    # query shape it exists for here is "find a path from an entry point to a
    # sink that does not pass through the guard" — the defect class that is
    # invisible to review, unit tests and coverage alike, because it lives in
    # the set of call sites rather than in any one file.
    codeql

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

    # ── Local AI agents ────────────────────────────────────────────────
    # Pi is the coding-agent harness for the local Muse Glimmer model.
    # llama.cpp is temporarily supplied by Homebrew because the pinned
    # nixpkgs build predates Glimmer support.
    pi-coding-agent

    # ── Infrastructure & Cloud ─────────────────────────────────────────
    google-cloud-sdk
    awscli2
    azure-cli
    kubectl
    kubernetes-helm
    stern
    kind
    # minikube 1.38.1 bundles its own bin/kubectl, which collides with the
    # standalone kubectl above in the home-manager profile buildEnv. Lower its
    # priority so the standalone kubectl wins that path; bin/minikube is
    # unaffected (it has no conflicting counterpart).
    (lib.lowPrio minikube)
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
