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

# Update all flake inputs
update:
    nix flake update

# Check flake validity
check:
    nix flake check

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

# Build starship-segments
build-starship:
    nix build .#starship-segments

# Build NixOS VM configuration (from macOS host)
vm-build:
    nix build .#nixosConfigurations.vm-aarch64.config.system.build.toplevel

# Garbage collect old generations
gc:
    nix-collect-garbage -d
