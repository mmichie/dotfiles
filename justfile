# Dotfiles management via Nix

# Apply system configuration
switch:
    @if [ "$(uname)" = "Darwin" ]; then \
        darwin-rebuild switch --flake .#mims-mbp; \
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
    else \
        home-manager build --flake .#mim@linux; \
    fi

# Build starship-segments
build-starship:
    nix build .#starship-segments
