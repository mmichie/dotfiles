#!/usr/bin/env bash
# Bootstrap script for macOS — installs Nix and applies nix-darwin config
# Usage: bash bootstrap.sh
#
# The host config comes from this machine's hostname, which must already match
# one of the flake's darwinConfigurations. FLAKE_REF=<host> can name the target
# explicitly, but it still has to agree with the hostname.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
SHORT_HOSTNAME="$(hostname -s)"
# The hostname is the source of truth for which host config to apply; FLAKE_REF
# only names it explicitly and is cross-checked against the hostname below.
FLAKE_REF="${FLAKE_REF:-$SHORT_HOSTNAME}"

echo "==> Bootstrapping macOS (flake: .#${FLAKE_REF}) from ${DOTFILES_DIR}"

# ── Pre-flight checks ─────────────────────────────────────────────
if [[ "$(uname)" != "Darwin" ]]; then
    echo "Error: this script is for macOS only."
    echo "For NixOS VM, use: hosts/vm-aarch64/install.sh"
    echo "For Linux, install Nix then run: nix run home-manager -- switch --flake .#mim@linux"
    exit 1
fi

# The switch at the end is by far the slowest step, so reject an unknown host
# now rather than after a full Nix install and build. A fresh machine has no
# nix yet, so read the host list out of flake.nix rather than `nix flake show`.
# `|| true` so a no-match or unreadable flake.nix falls through to the warning
# below rather than tripping `set -o pipefail`.
KNOWN_HOSTS="$(grep -oE '^[[:space:]]*"[^"]+"[[:space:]]*=[[:space:]]*mkDarwinHost' \
    "$DOTFILES_DIR/flake.nix" 2>/dev/null | sed -E 's/.*"([^"]+)".*/\1/' || true)"

if [[ -z "$KNOWN_HOSTS" ]]; then
    echo "==> Warning: no darwinConfigurations found in flake.nix, skipping host check"
elif ! printf '%s\n' "$KNOWN_HOSTS" | grep -qxF "$FLAKE_REF"; then
    echo "Error: '${FLAKE_REF}' is not a darwin host in this flake."
    echo ""
    echo "       Known hosts:"
    printf '%s\n' "$KNOWN_HOSTS" | sed 's/^/         /'
    echo ""
    echo "       The host comes from \`hostname -s\`, currently '${SHORT_HOSTNAME}'."
    echo "       Set the hostname to the host you want, then re-run:"
    echo ""
    echo "         sudo scutil --set HostName <host>"
    echo "         sudo scutil --set LocalHostName <host>"
    echo "         sudo scutil --set ComputerName <host>"
    echo ""
    echo "         ./bootstrap.sh"
    exit 1
fi

# nix-darwin sets networking.hostName, but the flake host has to be picked
# before that ever runs. Applying the wrong host's config is easy to do by
# accident and tedious to unpick, so require the two to agree up front rather
# than letting FLAKE_REF silently disagree with the machine it runs on.
if [[ "$SHORT_HOSTNAME" != "$FLAKE_REF" ]]; then
    echo "Error: hostname is '${SHORT_HOSTNAME}' but the target host is '${FLAKE_REF}'."
    echo "       Refusing to apply a host config that does not match this machine."
    echo ""
    echo "       Set the hostname to match, then re-run without FLAKE_REF:"
    echo ""
    echo "         sudo scutil --set HostName ${FLAKE_REF}"
    echo "         sudo scutil --set LocalHostName ${FLAKE_REF}"
    echo "         sudo scutil --set ComputerName ${FLAKE_REF}"
    echo ""
    echo "         ./bootstrap.sh"
    exit 1
fi

# flake.nix sets `inputs.self.submodules = true`, so the flake cannot be
# evaluated at all until the vendored tmux plugins are checked out — a plain
# `git clone` leaves them as empty gitlinks and every nix command dies on
# "Failed to fetch git repository". terminal.nix initializes them on each
# switch, but that fallback can never run when evaluation itself is what's
# blocked, so it has to happen here first.
if git -C "$DOTFILES_DIR" submodule status 2>/dev/null | grep -q '^-'; then
    echo "==> Initializing git submodules (vendored tmux plugins)"
    git -C "$DOTFILES_DIR" submodule update --init --recursive
fi

# ── Install Nix (Determinate Systems installer) ───────────────────
# On a sealed system volume /nix cannot be a real directory at /, so it has to
# be a synthetic entry the kernel materializes from /etc/synthetic.conf. The
# installer creates the "Nix Store" APFS volume before it needs that entry, so
# a missing entry fails it half-way: the volume exists with nowhere to mount,
# the receipt write falls through to the read-only root (EROFS), and re-running
# hits the same wall. Get /nix in place first.
ensure_nix_mount_point() {
    if [[ -d /nix ]]; then
        return 0
    fi

    echo "==> /nix is missing — preparing the APFS mount point (sudo required)"

    local orphan
    orphan="$(/usr/sbin/diskutil list 2>/dev/null |
        awk '/APFS Volume Nix Store/ { print $NF }' | head -1)"

    if [[ -n "$orphan" ]]; then
        echo "Error: a 'Nix Store' volume ($orphan) is left over from a failed install,"
        echo "       but /nix does not exist so it can never be mounted. That volume is"
        echo "       empty when the install failed this early — delete it and start clean:"
        echo ""
        echo "         sudo diskutil apfs deleteVolume $orphan"
        echo "         sudo sed -i.bak '/Determinate Nix Installer/d' /etc/fstab"
        echo "         sudo rm -f /usr/local/bin/determinate-nixd"
        echo ""
        echo "       Then re-run this script."
        exit 1
    fi

    sudo sh -c 'grep -qx nix /etc/synthetic.conf 2>/dev/null || printf "nix\n" >>/etc/synthetic.conf'
    sudo /System/Library/Filesystems/apfs.fs/Contents/Resources/apfs.util -t || true

    if [[ ! -d /nix ]]; then
        echo "Error: /nix is declared in /etc/synthetic.conf but not materialized yet."
        echo "       macOS needs a reboot to pick up a new synthetic entry."
        echo "       Reboot, then re-run this script."
        exit 1
    fi

    echo "    /nix is ready"
}

# A shell started before the install has no nix on PATH, so re-running this
# script in that same terminal would try to install over a working Nix. Pick up
# the profile first and let the check below see it.
if ! command -v nix &>/dev/null && [[ -f /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
    # shellcheck disable=SC1091
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

if ! command -v nix &>/dev/null; then
    ensure_nix_mount_point

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
    # shell.nix
    "$HOME/.zshrc"
    "$HOME/.zsh"
    "$HOME/.config/direnv"
    # terminal.nix
    "$HOME/.config/ghostty"
    "$HOME/.config/tmux"
    "$HOME/.config/nvim"
    "$HOME/.wezterm.lua"
    "$HOME/.ssh/config"
    # git.nix
    "$HOME/.gitconfig"
    "$HOME/.gitignore_global"
    # shared.nix
    "$HOME/bin"
    "$HOME/.inputrc"
    "$HOME/.actrc"
    "$HOME/.ideavimrc"
    "$HOME/.tmux-cht-command"
    "$HOME/.tmux-cht-languages"
    "$HOME/.config/btop/btop.conf"
    "$HOME/.config/htop/htoprc"
    "$HOME/.claude/CLAUDE.md"
    "$HOME/.claude/statusline-command.sh"
    "$HOME/.claude/commands/work.md"
    "$HOME/.claude/agents/development-tools/code-reviewer.md"
    "$HOME/.claude/agents/development-tools/refactoring-specialist.md"
    # hostclass/darwin-workstation.nix
    "$HOME/.config/aerospace"
    "$HOME/.config/karabiner"
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
# nix-darwin runs system activation as root, so this needs sudo. Resolve nix
# before escalating, because sudo does not necessarily carry the nix profile in
# its PATH — the same reason the justfile uses `sudo "$(command -v ...)"`.
sudo "$(command -v nix)" run nix-darwin -- switch --flake ".#${FLAKE_REF}"

# ── Start the GUI background services ─────────────────────────────
# The casks only install these apps; nothing launches them. Both register
# their own login item on first run, so on a fresh machine they stay absent
# until someone opens them by hand or logs out and back in -- no tiling and
# no key remapping on the machine you just finished setting up. Karabiner
# also needs a first run to prompt for Input Monitoring and its driver
# extension approval, neither of which can be granted headlessly.
#
# Second argument is the process to test for, which is not always the app
# name: Karabiner-Elements.app is the settings window, while
# karabiner_console_user_server is the service that actually applies the
# config, and that is what should decide whether there is work to do.
start_app() {
    local app="$1" proc="$2"
    if [[ ! -d "/Applications/$app.app" ]]; then
        echo "==> $app not installed, skipping (expected if Homebrew casks did not apply)"
    elif pgrep -xq "$proc"; then
        echo "==> $app already running"
    else
        echo "==> Starting $app"
        open -a "$app"
    fi
}

start_app AeroSpace AeroSpace
start_app Karabiner-Elements karabiner_console_user_server

echo ""
echo "==> Done! Open a new terminal to pick up all changes."
echo "    Future updates: just switch"
