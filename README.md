# dotfiles

Personal dotfiles managed by [Nix](https://nixos.org/) — nix-darwin on macOS, standalone home-manager on Linux. Config files live in `configs/` and are symlinked into `$HOME` via `mkOutOfStoreSymlink` (mutable — edits take effect immediately, no rebuild needed).

## Quick Start

```bash
# Install Nix
curl -sSf -L https://install.determinate.systems/nix | sh -s -- install

# Clone and apply
git clone https://github.com/mmichie/dotfiles ~/src/dotfiles
cd ~/src/dotfiles

# macOS
nix run nix-darwin -- switch --flake .#mims-mbp

# Linux
nix run home-manager -- switch --flake .#mim@linux
```

After the initial bootstrap, apply changes with:

```bash
just switch    # auto-detects macOS vs Linux
just update    # update flake inputs
just check     # validate flake
```

## What's Managed

**~120 CLI tools** via nixpkgs (`modules/home/packages.nix`):
ripgrep, fd, fzf, bat, eza, zoxide, atuin, delta, difftastic, starship, neovim, tmux, go, rustup, pyenv, kubectl, ansible, ffmpeg, and more.

**~25 macOS GUI apps** via Homebrew casks (`modules/darwin/homebrew.nix`):
Ghostty, AeroSpace, 1Password, Docker Desktop, Chrome, Obsidian, Spotify, etc.

**macOS defaults** (`modules/darwin/defaults.nix`):
Dock, Finder, keyboard, screenshots, spaces — applied on every `darwin-rebuild switch`.

**Shell** (`configs/zsh/`):
zsh with priority-based PATH management, lazy loading for slow tools (nvm, gcloud), cached init for atuin and vivid, custom starship prompt with a Rust binary for git status.

## Repo Layout

```
flake.nix                     # Entry point — darwinConfigurations + homeConfigurations
justfile                      # just switch / just update / just check
hosts/mims-mbp/               # nix-darwin system config + macOS home-manager overrides
home/                         # shared.nix (cross-platform), linux.nix
modules/
  darwin/                     # homebrew.nix (casks), defaults.nix (macOS prefs)
  home/                       # packages, shell, git, editor, terminal modules
configs/
  aerospace/                  # Tiling window manager (DWM-style)
  ghostty/                    # Terminal emulator
  git/                        # .gitconfig, .gitignore_global
  karabiner/                  # Keyboard remapping
  nvim/                       # Neovim config (lazy.nvim)
  ssh/                        # SSH config
  starship/                   # Prompt config + helper scripts
  system/                     # .inputrc, .dircolors, location service
  tmux/                       # tmux.conf + plugins (git submodules)
  wezterm/                    # Backup terminal emulator
  zsh/                        # .zshrc + modular zsh libraries
bin/                          # Personal scripts + platform binaries
starship-segments/            # Rust source for custom prompt segments (built by Crane)
```

## Design Decisions

- **Mutable symlinks**: `mkOutOfStoreSymlink` points symlinks at the git working tree, not the Nix store. Edit a config, see the change. Same workflow as GNU Stow.
- **CLI from Nix, GUI from Homebrew**: Nix handles all command-line tools cross-platform. macOS GUI apps stay as Homebrew casks because `.app` bundles don't work well from the Nix store.
- **Crane for Rust**: The custom `starship-segments` binary is built as a Nix derivation via Crane, with pinned libgit2 — no more broken dylib links when Homebrew updates.
- **Declarative cleanup**: `homebrew.onActivation.cleanup = "zap"` removes any cask not in the config. The declared list is the source of truth.

## See Also

- https://github.com/ThePrimeagen/.dotfiles
- https://github.com/xero/dotfiles
- https://github.com/r00k
- https://github.com/tpope/tpope
- https://github.com/benbernard/HomeDir
- https://github.com/ninrod/dotfiles
- https://github.com/aaronbieber/dotfiles
- https://github.com/sectioneight/dotfiles
