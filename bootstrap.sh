#!/usr/bin/env bash
# Bootstrap script for macOS — installs Nix and applies nix-darwin config
# Usage: bash bootstrap.sh
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
FLAKE_REF="mims-mbp"

echo "==> Bootstrapping macOS from ${DOTFILES_DIR}"

# ── Pre-flight checks ─────────────────────────────────────────────
if [[ "$(uname)" != "Darwin" ]]; then
  echo "Error: this script is for macOS only."
  echo "For NixOS VM, use: hosts/vm-aarch64/install.sh"
  echo "For Linux, install Nix then run: nix run home-manager -- switch --flake .#mim@linux"
  exit 1
fi

# ── Install Nix (Determinate Systems installer) ───────────────────
if ! command -v nix &>/dev/null; then
  echo "==> Installing Nix (Determinate Systems)"
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install --no-confirm

  # Source nix profile so it's available in this session
  if [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
    # shellcheck disable=SC1091
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  fi

  if ! command -v nix &>/dev/null; then
    echo "Error: nix not found after install. Open a new terminal and re-run this script."
    exit 1
  fi
else
  echo "==> Nix already installed, skipping"
fi

# ── Remove conflicting files ──────────────────────────────────────
# home-manager will fail if real files exist at symlink targets
CONFLICTS=()
SYMLINK_TARGETS=(
  "$HOME/.zshrc"
  "$HOME/.zsh"
  "$HOME/.config/tmux"
  "$HOME/.config/nvim"
  "$HOME/.config/ghostty"
  "$HOME/.config/direnv"
  "$HOME/.config/starship.toml"
  "$HOME/.wezterm.lua"
  "$HOME/.inputrc"
  "$HOME/.dircolors"
)

for target in "${SYMLINK_TARGETS[@]}"; do
  if [[ -e "$target" && ! -L "$target" ]]; then
    CONFLICTS+=("$target")
  fi
done

if [[ ${#CONFLICTS[@]} -gt 0 ]]; then
  echo "==> Found existing files that conflict with home-manager symlinks:"
  for f in "${CONFLICTS[@]}"; do
    echo "    $f"
  done

  read -rp "    Back these up to ~/.dotfiles-backup and continue? [y/N] " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    for f in "${CONFLICTS[@]}"; do
      echo "    Moving $f -> $BACKUP_DIR/"
      mv "$f" "$BACKUP_DIR/"
    done
  else
    echo "    Aborting. Move these files manually and re-run."
    exit 1
  fi
fi

# ── Apply nix-darwin configuration ────────────────────────────────
echo "==> Applying nix-darwin configuration (this takes a while on first run)"
cd "$DOTFILES_DIR"
nix run nix-darwin -- switch --flake ".#${FLAKE_REF}"

echo ""
echo "==> Done! Open a new terminal to pick up all changes."
echo "    Future updates: just switch"
