#!/bin/bash

# Change to the directory where the script is located
cd "$(dirname "$0")"

# Update Git submodules
echo "Updating git submodules..."
git submodule update --init --recursive
if [ $? -ne 0 ]; then
    echo "Failed to update git submodules."
    exit 1
fi

# List of directories to stow
stow_dirs=("utils" "tmux" "system" "ssh" "osx" "mail" "git" "fonts" "brew" "x11" "bin" "screen" "vim" "bash" "zsh" "yabai" "wezterm" "eza" "aerospace")

# Stow directories
echo "Stowing directories..."
for dir in "${stow_dirs[@]}"; do
    if [ -d "$dir" ]; then
        stow "$dir" -t ~
        if [ $? -eq 0 ]; then
            echo "Successfully stowed $dir"
        else
            echo "Failed to stow $dir"
        fi
    else
        echo "Directory $dir does not exist, skipping..."
    fi
done

echo "Stow process completed."

