# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal dotfiles managed by **Nix** — nix-darwin on macOS, full NixOS in a VM, standalone home-manager on Linux. Config files live in `configs/` and are symlinked into `$HOME` via `mkOutOfStoreSymlink` (mutable — edits take effect immediately without rebuilding).

- **~120 CLI tools** declared in `modules/home/packages.nix`
- **~25 macOS GUI apps** as Homebrew casks in `modules/darwin/homebrew.nix`
- **macOS defaults** in `modules/darwin/defaults.nix`
- **Custom Rust binary** (`starship-segments`) built via Crane in `flake.nix`

## Common Commands

### Apply Configuration
```bash
# Apply everything (auto-detects macOS vs Linux vs NixOS)
just switch

# macOS explicitly
darwin-rebuild switch --flake .#mims-mbp

# NixOS VM explicitly
sudo nixos-rebuild switch --flake .#vm-aarch64

# Linux explicitly
home-manager switch --flake .#mim@linux

# Build NixOS VM config from macOS host
just vm-build

# Update flake inputs
just update

# Validate flake
just check
```

### Fresh Machine Bootstrap
```bash
# 1. Install Nix (Determinate Systems installer)
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install

# 2. Clone and apply
git clone https://github.com/mmichie/dotfiles ~/src/dotfiles
cd ~/src/dotfiles

# macOS:
nix run nix-darwin -- switch --flake .#mims-mbp

# Linux:
nix run home-manager -- switch --flake .#mim@linux
```

### Development Commands
```bash
# Reload zsh configuration
source ~/.zshrc

# Build starship-segments binary
just build-starship

# Dry-run to see what would change
just dry-run
```

## Architecture

### Directory Structure
```
flake.nix                     # Entry point — darwinConfigurations + homeConfigurations
flake.lock                    # Pinned input versions
justfile                      # just switch / just update / just check / just dry-run
hosts/mims-mbp/               # nix-darwin system config + macOS home-manager overrides
hosts/vm-aarch64/             # NixOS VM config (DWM, VMware, aarch64-linux)
home/                         # shared.nix (cross-platform), linux.nix
modules/darwin/               # homebrew.nix (casks), defaults.nix (macOS prefs)
modules/home/                 # packages, shell, git, editor, terminal modules
configs/                      # Raw config files (symlinked by home-manager)
  aerospace/ ghostty/ git/ karabiner/ nvim/ ssh/ starship/ system/ tmux/ wezterm/ zsh/
bin/                          # Personal scripts
starship-segments/            # Rust source (built by Crane)
```

### Key Design Decisions
- **`mkOutOfStoreSymlink`**: Config files are symlinked from the repo, not copied into the Nix store. Edits take effect immediately without rebuilding.
- **CLI tools via nixpkgs**: All command-line tools are declared in `modules/home/packages.nix`
- **GUI apps via Homebrew casks**: macOS GUI apps stay in `modules/darwin/homebrew.nix` (nix can't manage .app bundles well)
- **Crane for Rust builds**: `starship-segments` binary is built via Crane in `flake.nix`

### Key Components

#### Environment & PATH
`configs/zsh/.zsh/lib/environment.zsh` configures PATH via `typeset -U path` (zsh native dedup):
- User paths: `$HOME/bin`, `$HOME/.local/bin`, `$HOME/.claude/local`
- Nix profile paths: `~/.nix-profile/bin`, `/etc/profiles/per-user/$USER/bin`
- Language paths: Go
- Re-runs `setup_path` on macOS login shells to fix path_helper reordering

#### Shell Configuration
`configs/zsh/.zshrc` uses a modular design with optimized startup:
- Core libraries loaded in order: platform_detection → environment → shell → prompt
- Tools: atuin (history), vivid (ls colors), starship (prompt), fzf, zoxide

## Platform Targets

| Target | System | Entry point | Command |
|--------|--------|-------------|---------|
| macOS (mims-mbp) | aarch64-darwin | `darwinConfigurations."mims-mbp"` | `darwin-rebuild switch --flake .#mims-mbp` |
| NixOS VM (vm-aarch64) | aarch64-linux | `nixosConfigurations."vm-aarch64"` | `sudo nixos-rebuild switch --flake .#vm-aarch64` |
| Linux | x86_64-linux | `homeConfigurations."mim@linux"` | `home-manager switch --flake .#mim@linux` |

## Dependencies
- **Nix**: Package manager (Determinate Systems installer)
- **nix-darwin** (macOS): System-level config + Homebrew cask management
- **home-manager**: User-level config, packages, and symlinks
- **Homebrew** (macOS only): GUI app casks — CLI tools come from nixpkgs
- **Crane**: Builds the starship-segments Rust binary
