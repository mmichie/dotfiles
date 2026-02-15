#!/usr/bin/env bash
# NixOS VM install script — run from the minimal ISO
# Usage: curl -L <raw-github-url> | bash
#   or:  nix-shell -p git --run 'git clone ... && bash dotfiles/hosts/vm-aarch64/install.sh'
set -euo pipefail

DISK="/dev/sda"
FLAKE_REPO="https://github.com/mmichie/dotfiles"
FLAKE_REF="vm-aarch64"
USERNAME="mim"

# Auto-detect disk: NVMe (VMware Fusion Apple Silicon) > virtio > SCSI
if [ -b /dev/nvme0n1 ]; then
  DISK="/dev/nvme0n1"
elif [ -b /dev/vda ]; then
  DISK="/dev/vda"
fi

echo "==> Installing NixOS to ${DISK}"
echo "    This will ERASE the entire disk."
read -rp "    Continue? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || exit 1

# ── Partition (GPT + EFI) ────────────────────────────────────────
echo "==> Partitioning ${DISK}"
parted "${DISK}" -- mklabel gpt
parted "${DISK}" -- mkpart boot fat32 1MiB 512MiB
parted "${DISK}" -- set 1 esp on
parted "${DISK}" -- mkpart nixos ext4 512MiB 100%

# Settle udev so /dev/disk/by-label appears
udevadm settle

# Handle both sda1/sda2 and vda1/vda2 and nvme0n1p1/p2
PART1="${DISK}1"
PART2="${DISK}2"
if [[ "${DISK}" == *nvme* ]]; then
  PART1="${DISK}p1"
  PART2="${DISK}p2"
fi

# ── Format with labels ──────────────────────────────────────────
echo "==> Formatting"
mkfs.fat -F 32 -n boot "${PART1}"
mkfs.ext4 -L nixos "${PART2}"

# ── Mount ────────────────────────────────────────────────────────
echo "==> Mounting"
mount "${PART2}" /mnt
mkdir -p /mnt/boot
mount -o fmask=0077,dmask=0077 "${PART1}" /mnt/boot

# ── Clone dotfiles ───────────────────────────────────────────────
echo "==> Cloning dotfiles"
DOTFILES="/mnt/home/${USERNAME}/src/dotfiles"
mkdir -p "$(dirname "${DOTFILES}")"
nix-shell -p git --run "git clone ${FLAKE_REPO} ${DOTFILES}"

# ── Install NixOS ────────────────────────────────────────────────
echo "==> Installing NixOS (this takes a while)"
nixos-install --flake "${DOTFILES}#${FLAKE_REF}" --no-root-passwd --option download-buffer-size 268435456

# ── Set passwords (use chroot directly — nixos-enter has sudo setuid issues) ──
echo "==> Set password for ${USERNAME}"
chroot /mnt passwd "${USERNAME}"
echo "==> Set root password"
chroot /mnt passwd root

# ── Fix ownership ────────────────────────────────────────────────
chown -R 1000:100 "/mnt/home/${USERNAME}"

echo ""
echo "==> Done! Run 'reboot' to boot into NixOS."
