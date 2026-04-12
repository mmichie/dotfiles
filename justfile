# Dotfiles management via Nix

# Apply system configuration
switch:
    @if [ "$(uname)" = "Darwin" ]; then \
        sudo darwin-rebuild switch --flake .#mims-mbp; \
    elif [ -f /etc/NIXOS ]; then \
        sudo nixos-rebuild switch --flake .#vm-aarch64; \
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
        darwin-rebuild build --flake .#mims-mbp && nvd diff /run/current-system result; \
    elif [ -f /etc/NIXOS ]; then \
        nixos-rebuild dry-activate --flake .#vm-aarch64; \
    else \
        home-manager build --flake .#mim@linux; \
    fi

# Format all nix files
fmt:
    nix fmt

# Build NixOS VM configuration (from macOS host)
vm-build:
    nix build .#nixosConfigurations.vm-aarch64.config.system.build.toplevel

# Garbage collect old generations
gc:
    nix-collect-garbage -d
