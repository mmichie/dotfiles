# Dotfiles management via Nix

# Apply system configuration (detects host via `hostname -s` on Darwin/NixOS)
switch:
    @if [ "$(uname)" = "Darwin" ]; then \
        sudo darwin-rebuild switch --flake ".#$(hostname -s)"; \
    elif [ -f /etc/NIXOS ]; then \
        sudo nixos-rebuild switch --flake ".#$(hostname -s)"; \
    else \
        home-manager switch --flake .#mim@linux; \
    fi

# Update all flake inputs and show what changed
update:
    @cp flake.lock /tmp/flake.lock.before
    nix flake update
    @echo ""
    @echo "=== Updated inputs ==="
    @diff \
        <(jq -r '.nodes | to_entries[] | select(.value.locked.rev != null) | "\(.key) \(.value.locked.rev[0:7])"' /tmp/flake.lock.before | sort) \
        <(jq -r '.nodes | to_entries[] | select(.value.locked.rev != null) | "\(.key) \(.value.locked.rev[0:7])"' flake.lock | sort) \
        | grep '^[<>]' || echo "No inputs changed."
    @rm -f /tmp/flake.lock.before

# Check flake validity
check:
    nix flake check --all-systems

# Show what would change
dry-run:
    @if [ "$(uname)" = "Darwin" ]; then \
        darwin-rebuild build --flake ".#$(hostname -s)" && nvd diff /run/current-system result; \
    elif [ -f /etc/NIXOS ]; then \
        nixos-rebuild dry-activate --flake ".#$(hostname -s)"; \
    else \
        home-manager build --flake .#mim@linux; \
    fi

# Format all nix files
fmt:
    nix fmt

# Build NixOS VM configuration (from macOS host)
vm-build:
    nix build .#nixosConfigurations.vm-aarch64.config.system.build.toplevel

# Copy local config to VM and apply NixOS rebuild (requires VM to be running)
vm-switch:
    rsync -av --rsync-path="sudo rsync" \
        --exclude='.git/' \
        --exclude='result' \
        . vm:/nix-config
    ssh vm "sudo nixos-rebuild switch --flake /nix-config#vm-aarch64"

# Backup SSH keys and GPG keyring to backup.tar.gz (for machine migration)
secrets-backup:
    tar -czvf backup.tar.gz \
        -C "$HOME" \
        --exclude='.gnupg/.#*' \
        --exclude='.gnupg/S.*' \
        --exclude='.gnupg/*.conf' \
        --exclude='.ssh/environment' \
        .ssh/ \
        .gnupg/

# Restore SSH keys and GPG keyring from backup.tar.gz
secrets-restore:
    @[ -f backup.tar.gz ] || (echo "Error: backup.tar.gz not found"; exit 1)
    tar -xzvf backup.tar.gz -C "$HOME"
    chmod 700 "$HOME/.ssh" "$HOME/.gnupg"
    chmod 600 "$HOME/.ssh/"* || true

# Open nix repl with all flake outputs pre-loaded (configs, formatter, etc.)
repl:
    cd {{justfile_directory()}} && nix repl .

# Garbage collect old generations
gc:
    nix-collect-garbage -d
