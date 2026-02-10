# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal dotfiles repository that uses GNU Stow for symlink management. The dotfiles are organized by tool/topic, with each directory containing configuration files that get symlinked to the home directory.

## Common Commands

### Installation and Setup
```bash
# Full new-machine setup (Homebrew, packages, stow, macOS defaults)
./bootstrap.sh

# Stow only (symlink configs to home directory)
./stow.sh

# Install specific configuration
stow -t ~ zsh  # Example: install only zsh configs

# Install packages from Brewfile
brew bundle --file=brew/Brewfile
```

### Development Commands
```bash
# When modifying PATH management or shell configuration
source ~/.zshrc  # Reload zsh configuration

# Check PATH configuration
path_show        # Shows PATH entries grouped by priority
path_which       # Shows order in PATH
```

## Architecture

### Directory Structure
- **Topic-based organization**: Each directory represents a specific tool (e.g., `vim/`, `tmux/`, `git/`)
- **Platform-specific**: `osx/` for macOS, `x11/` for Linux/X11
- **Binary management**: `bin/bin/` contains various tools with platform-specific versions

### Key Components

#### PATH Management System
Located in `zsh/.zsh/lib/path_manager.zsh`, implements a priority-based PATH management:
- Groups: user (1), language (2), tools (3), system (4), default (5)
- Functions: `path_add`, `path_build`, `path_show`, `path_which`
- Handles macOS path_helper issues by rebuilding PATH for login shells

#### Environment Setup
`zsh/.zsh/lib/environment.zsh` configures:
- User paths: `$HOME/bin`, `$HOME/.local/bin`, `$HOME/.claude/local`
- Language paths: Go, Rust, Python (via pyenv)
- Lazy loading for: Homebrew, nvm, gcloud SDK

#### Shell Configuration
`.zshrc` uses a modular design with optimized startup:
- Core libraries loaded in order: path_manager → environment → shell functions
- Lazy loading for heavy tools to improve startup time
- Recent additions: atuin (history), vivid (ls colors)

### Installation Process
1. `bootstrap.sh` installs Xcode CLI tools, Homebrew, and packages from `brew/Brewfile`
2. `stow.sh` updates git submodules and symlinks configs to the home directory
3. Stowed configs: aerospace, bin, ghostty, git, karabiner, nvim, osx, ssh, system, tmux, wezterm, zsh

## Dependencies
- **GNU Stow**: Required for dotfile management
- **Git submodules**: diff-so-fancy
- **Homebrew** (macOS): Package manager, packages declared in `brew/Brewfile`
- **Platform binaries**: fzf, intu (multiple architectures in `bin/bin/`)