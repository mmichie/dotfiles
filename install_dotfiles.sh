#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

# Update Git submodules
echo "Updating git submodules..."
git submodule update --init --recursive

# Directories to stow (alphabetical)
stow_dirs=(
    aerospace
    bin
    ghostty
    git
    karabiner
    nvim
    osx
    ssh
    system
    tmux
    wezterm
    zsh
)

# Stow directories
echo "Stowing directories..."
for dir in "${stow_dirs[@]}"; do
    if [ -d "$dir" ]; then
        stow "$dir" -t ~
        echo "  stowed $dir"
    else
        echo "  skipped $dir (not found)"
    fi
done

echo "Stow complete."
