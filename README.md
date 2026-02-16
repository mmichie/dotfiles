# dotfiles

Personal dotfiles managed by [Nix](https://nixos.org/) — nix-darwin on macOS, full NixOS in a VM, standalone home-manager on Linux. Config files live in `configs/` and are symlinked into `$HOME` via `mkOutOfStoreSymlink` (mutable — edits take effect immediately, no rebuild needed).

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

# NixOS VM (after minimal NixOS install in VMware Fusion)
sudo nixos-rebuild switch --flake ~/src/dotfiles#vm-aarch64
```

After the initial bootstrap, apply changes with:

```bash
just switch    # auto-detects macOS vs Linux vs NixOS
just update    # update flake inputs
just check     # validate flake
```

## What's Managed

**~120 CLI tools** via nixpkgs (`modules/home/packages.nix`):
ripgrep, fd, fzf, bat, eza, zoxide, atuin, delta, difftastic, starship, neovim, tmux, go, cargo, nodejs, kubectl, ansible, ffmpeg, and more.

**~25 macOS GUI apps** via Homebrew casks (`modules/darwin/homebrew.nix`):
Ghostty, AeroSpace, 1Password, Docker Desktop, Chrome, Obsidian, Spotify, etc.

**macOS defaults** (`modules/darwin/defaults.nix`):
Dock, Finder, keyboard, screenshots, spaces — applied on every `darwin-rebuild switch`.

**Shell** (`configs/zsh/`):
zsh with modular config, custom starship prompt with a Rust binary for git status, atuin history, vivid ls colors.

## Repo Layout

```
flake.nix                     # Entry point — darwinConfigurations + homeConfigurations
justfile                      # just switch / just update / just check
hosts/mims-mbp/               # nix-darwin system config + macOS home-manager overrides
hosts/vm-aarch64/             # NixOS VM (DWM + VMware Fusion on Apple Silicon)
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

## NixOS VM (VMware Fusion on Apple Silicon)

A full NixOS dev environment running DWM, inside VMware Fusion on your M-series Mac.

### Setup

1. Download the NixOS aarch64 minimal ISO from [nixos.org](https://nixos.org/download)
2. Create a new VM in VMware Fusion (4GB+ RAM, 50GB+ disk recommended)
3. Boot the ISO and install a minimal NixOS (partition disk, `nixos-install`, reboot)
4. Clone and apply:

```bash
git clone https://github.com/mmichie/dotfiles ~/src/dotfiles
cd ~/src/dotfiles
sudo nixos-rebuild switch --flake .#vm-aarch64
# Reboot — DWM + full dev environment ready
```

### Daily use

`just switch` auto-detects NixOS via `/etc/NIXOS`. Pull config changes from git and re-run.

### DWM keybindings

| Key | Action |
|-----|--------|
| `Mod+Enter` | Open terminal (st) |
| `Mod+p` | dmenu launcher |
| `Mod+j/k` | Focus next/prev window |
| `Mod+Shift+c` | Close window |
| `Mod+Shift+q` | Quit DWM |
| `Mod+1-9` | Switch tag |
| `Mod+t/f/m` | Tiled/floating/monocle layout |

`Mod` is `Super` (Command key on Mac keyboard via VMware Fusion).

## See Also

- https://github.com/ThePrimeagen/.dotfiles
- https://github.com/xero/dotfiles
- https://github.com/r00k
- https://github.com/tpope/tpope
- https://github.com/benbernard/HomeDir
- https://github.com/ninrod/dotfiles
- https://github.com/aaronbieber/dotfiles
- https://github.com/sectioneight/dotfiles
