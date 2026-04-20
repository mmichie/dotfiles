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
just switch          # auto-detects macOS vs Linux vs NixOS
just update          # update flake inputs and show what changed
just dry-run         # preview what would change without applying
just check           # validate flake for all systems
just fmt             # format all nix files
just gc              # garbage collect old generations
just vm-switch       # rsync config to VM and apply nixos-rebuild
just secrets-backup  # tar .ssh + .gnupg to backup.tar.gz
just secrets-restore # restore from backup.tar.gz
```

## What's Managed

**~120 CLI tools** via nixpkgs (`modules/home/packages-core.nix`):
ripgrep, fd, fzf, bat, eza, zoxide, atuin, delta, difftastic, neovim, tmux, nvd, statix, rclone, restic, hexyl, tealdeer, transcrypt, and more.

**Dev toolchains** via nixpkgs (`modules/home/packages-dev.nix`):
Go, Rust, Python, Node.js, Java, kubectl, helm, ansible, awscli, opentofu, ffmpeg, pandoc, and nerd fonts.

**~25 macOS GUI apps** via Homebrew casks (`modules/darwin/homebrew.nix`):
Ghostty, AeroSpace, 1Password, Chrome, Obsidian, Zed, Slack, Discord, Spotify, etc.

**macOS defaults** (`modules/darwin/defaults.nix`):
Dock, Finder, keyboard, screenshots, spaces, firewall — applied on every `darwin-rebuild switch`.

**Shell** (`configs/zsh/`):
zsh with a modular library system, [`plx`](https://github.com/mmichie/plx) prompt (powerline segments in Rust), atuin history with fzf integration, vivid ls colors, tmux emoji window titles.

## Repo Layout

```
flake.nix                     # Entry point — darwinConfigurations + homeConfigurations
flake.lock                    # Pinned input versions
justfile                      # Task runner (switch, update, vm-switch, secrets, etc.)
lefthook.yml                  # Pre-commit hooks (nix-fmt, statix, shellcheck, conventional commits)
lib/
  mkHost.nix                  # Host constructors — mkDarwinHost, mkNixosHost, mkHomeConfig
hosts/
  mims-mbp/                   # nix-darwin system config (Touch ID sudo, launchd GC, Spotlight)
  vm-aarch64/                 # NixOS VM (DWM + VMware Fusion on Apple Silicon)
hostclass/
  darwin-workstation.nix      # macOS-specific home config (aerospace, karabiner)
  linux-workstation.nix       # Linux-specific home config (clipboard tools, git signing)
home/
  shared.nix                  # Cross-platform home-manager base
  linux.nix                   # Standalone Linux overrides
modules/
  darwin/
    homebrew.nix              # ~25 GUI casks, auto-removes unlisted apps on activation
    defaults.nix              # macOS system preferences
  home/
    options.nix               # Custom Nix options (my.user.*, my.dotfilesPath)
    packages-core.nix         # ~120 CLI tools (all platforms)
    packages-dev.nix          # Dev toolchains + fonts (workstations only)
    shell.nix                 # zsh + direnv symlinks
    git.nix                   # .gitconfig + .gitignore_global symlinks
    editor.nix                # Neovim config symlink
    terminal.nix              # Ghostty, WezTerm, tmux, SSH config + authorized keys
configs/
  aerospace/                  # Tiling window manager (macOS)
  direnv/                     # direnvrc + direnv.toml (auto-allows ~/src/)
  ghostty/                    # Terminal emulator
  git/                        # .gitconfig, .gitignore_global
  karabiner/                  # Keyboard remapping (macOS)
  nvim/                       # Neovim config (lazy.nvim)
  ssh/                        # SSH client config
  system/                     # .inputrc + tmux-cht cheat sheet lists
  tmux/                       # tmux.conf + plugins (git submodules)
  wezterm/                    # Backup terminal emulator
  zsh/                        # .zshrc + modular zsh libraries
bin/                          # Personal scripts + platform binaries
.github/workflows/
  check.yml                   # CI: nix flake check + fmt on push
```

## Design Decisions

- **Mutable symlinks**: `mkOutOfStoreSymlink` points symlinks at the git working tree, not the Nix store. Edit a config, see the change immediately. Same workflow as GNU Stow.
- **CLI from Nix, GUI from Homebrew**: Nix handles all command-line tools cross-platform. macOS GUI apps stay as Homebrew casks because `.app` bundles don't work well from the Nix store.
- **Host classes**: `lib/mkHost.nix` defines `darwin-workstation` and `linux-workstation` classes that compose module sets. Adding a new host is one `mkDarwinHost` or `mkNixosHost` call plus a thin hardware config.
- **Flake inputs for custom tools**: [`plx`](https://github.com/mmichie/plx) (powerline segments) lives in its own repo and is consumed as a flake input, built via Crane.
- **Declarative Homebrew cleanup**: `cleanup = "uninstall"` removes any cask not listed in the config. (`"zap"` is avoided — it breaks Docker Desktop receipts.)
- **Pre-commit hooks**: lefthook enforces nix-fmt formatting, statix linting, shellcheck, and conventional commit messages on every commit.

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

`just switch` auto-detects NixOS via `/etc/NIXOS`. To apply changes from your Mac without SSHing in manually:

```bash
just vm-switch   # rsyncs local config to /nix-config on the VM and rebuilds
```

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

[mitchellh/nixos-config](https://github.com/mitchellh/nixos-config) was the original inspiration for this Nix rewrite. [patsoffice/dotfiles](https://github.com/patsoffice/dotfiles) grew out of this repo and has been a mutual source of ideas — both configs have evolved together.

Other dotfiles worth reading:

- https://github.com/ThePrimeagen/.dotfiles
- https://github.com/xero/dotfiles
- https://github.com/r00k
- https://github.com/tpope/tpope
- https://github.com/benbernard/HomeDir
- https://github.com/ninrod/dotfiles
- https://github.com/aaronbieber/dotfiles
- https://github.com/sectioneight/dotfiles
