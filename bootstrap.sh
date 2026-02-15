#!/bin/bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
info()  { printf '\033[1;34m==> %s\033[0m\n' "$*"; }
warn()  { printf '\033[1;33m==> %s\033[0m\n' "$*"; }
error() { printf '\033[1;31m==> %s\033[0m\n' "$*"; exit 1; }

# -----------------------------------------------------------------------------
# Sudo
# -----------------------------------------------------------------------------
# Some casks (e.g. tailscale) require sudo for kernel extensions / installers.
# Ask once upfront and keep the credential cached for the duration of bootstrap.
info "Requesting sudo access (needed for some cask installs)..."
sudo -v
# Keep sudo alive in the background until this script exits
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null' EXIT

# -----------------------------------------------------------------------------
# Platform detection
# -----------------------------------------------------------------------------
OS="$(uname -s)"
case "$OS" in
    Darwin) ;;
    *)      error "Unsupported platform: $OS (only macOS is supported for now)" ;;
esac

# -----------------------------------------------------------------------------
# Xcode Command Line Tools
# -----------------------------------------------------------------------------
if ! xcode-select -p &>/dev/null; then
    info "Installing Xcode Command Line Tools..."
    xcode-select --install
    echo "Press any key after the installation completes."
    read -n 1 -s
fi

# -----------------------------------------------------------------------------
# Homebrew
# -----------------------------------------------------------------------------
if ! command -v brew &>/dev/null; then
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add brew to PATH for the rest of this script
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

info "Updating Homebrew..."
brew update

# -----------------------------------------------------------------------------
# Brew Bundle (install packages from Brewfile)
# -----------------------------------------------------------------------------
info "Installing packages from Brewfile..."
if ! brew bundle --file="$DOTFILES_DIR/brew/Brewfile"; then
    warn "Some Brewfile dependencies failed to install (see above)."
    warn "You can retry later with: brew bundle --file=brew/Brewfile"
fi

# -----------------------------------------------------------------------------
# Claude Code
# -----------------------------------------------------------------------------
if ! command -v claude &>/dev/null && [ ! -x "$HOME/.local/bin/claude" ]; then
    info "Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | bash
fi

# -----------------------------------------------------------------------------
# Beads CLI
# -----------------------------------------------------------------------------
if ! command -v beads &>/dev/null; then
    info "Installing Beads CLI..."
    curl -fsSL https://raw.githubusercontent.com/steveyegge/beads/main/scripts/install.sh | bash
fi

# -----------------------------------------------------------------------------
# Git submodules
# -----------------------------------------------------------------------------
info "Updating git submodules..."
cd "$DOTFILES_DIR"
git submodule update --init --recursive

# -----------------------------------------------------------------------------
# Stow dotfiles
# -----------------------------------------------------------------------------
info "Stowing dotfiles..."
"$DOTFILES_DIR/stow.sh"

# -----------------------------------------------------------------------------
# macOS defaults
# -----------------------------------------------------------------------------
if [ -f "$DOTFILES_DIR/osx/.osx" ]; then
    read -p "Apply macOS defaults? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        info "Applying macOS defaults..."
        source "$DOTFILES_DIR/osx/.osx"
        warn "Some changes require a logout or restart to take effect."
    fi
fi

# -----------------------------------------------------------------------------
# Done
# -----------------------------------------------------------------------------
info "Bootstrap complete."
echo ""
echo "Next steps:"
echo "  - Restart your terminal (or source ~/.zshrc)"
echo "  - Sign into 1Password, browsers, etc."
echo "  - Set up SSH keys and GPG keys"
