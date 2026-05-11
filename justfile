# Dotfiles management via Nix

# Apply system configuration (detects host via `hostname -s` on Darwin/NixOS)
switch:
    @if [ "$(uname)" = "Darwin" ]; then \
        sudo "$(command -v darwin-rebuild)" switch --flake ".#$(hostname -s)"; \
    elif [ -f /etc/NIXOS ]; then \
        sudo "$(command -v nixos-rebuild)" switch --flake ".#$(hostname -s)"; \
    else \
        home-manager switch --flake .#mim@linux; \
    fi

# Update all flake inputs, show input + package diffs
update: && dry-run
    @cp flake.lock /tmp/flake.lock.before
    nix flake update
    @echo ""
    @echo "=== Updated inputs ==="
    @diff \
        <(jq -r '.nodes | to_entries[] | select(.value.locked.rev != null) | "\(.key) \(.value.locked.rev[0:7])"' /tmp/flake.lock.before | sort) \
        <(jq -r '.nodes | to_entries[] | select(.value.locked.rev != null) | "\(.key) \(.value.locked.rev[0:7])"' flake.lock | sort) \
        | grep '^[<>]' || echo "No inputs changed."
    @rm -f /tmp/flake.lock.before
    @echo ""
    @echo "=== Package diff ==="

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

# Measure interactive zsh startup time. Runs N timed shells after a warmup,
# reports min/median/max, fails if median exceeds the budget (default 250ms).
# Use `just profile 300` to override the budget, or `just profile-deep` for
# a zprof breakdown of where the time is spent.
profile budget_ms="250" runs="10":
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Profiling zsh startup ({{runs}} runs after 1 warmup, budget {{budget_ms}}ms)..."
    zsh -ic exit >/dev/null 2>&1  # warmup: pre-populate fs cache, compinit dump, etc.
    samples=$(for _ in $(seq 1 {{runs}}); do
        /usr/bin/time -p zsh -ic exit 2>&1 | awk '/^real/ {printf "%d\n", $2 * 1000}'
    done | sort -n)
    min=$(echo "$samples" | head -1)
    median=$(echo "$samples" | sed -n "$(( {{runs}} / 2 + 1 ))p")
    max=$(echo "$samples" | tail -1)
    printf "  min:    %4d ms\n  median: %4d ms\n  max:    %4d ms\n  budget: %4d ms\n" \
        "$min" "$median" "$max" "{{budget_ms}}"
    if (( median > {{budget_ms}} )); then
        echo "FAIL: median exceeds budget — run \`just profile-deep\` to investigate"
        exit 1
    fi
    echo "OK"

# Show zprof breakdown of zsh startup (which functions are slow). Uses the
# PROFILE_STARTUP hook in .zshrc which loads zsh/zprof and dumps a report.
profile-deep:
    @PROFILE_STARTUP=1 zsh -ic exit 2>&1 | head -40

# Refresh vendored Claude Code agents from davila7/claude-code-templates upstream
claude-update:
    #!/usr/bin/env bash
    set -euo pipefail
    cd {{justfile_directory()}}
    AGENTS=(
        "development-tools/code-reviewer.md"
        "development-tools/refactoring-specialist.md"
    )
    for agent in "${AGENTS[@]}"; do
        local="configs/claude/agents/${agent}"
        tmp=$(mktemp)
        gh api "repos/davila7/claude-code-templates/contents/cli-tool/components/agents/${agent}" --jq .content \
            | base64 -d > "$tmp"
        if cmp -s "$local" "$tmp"; then
            echo "up-to-date: ${agent}"
            rm -f "$tmp"
            continue
        fi
        echo
        echo "=== ${agent} ==="
        diff -u "$local" "$tmp" || true
        read -rp "Overwrite? [y/N] " yn
        if [[ "$yn" =~ ^[Yy]$ ]]; then
            mv "$tmp" "$local"
            echo "updated: ${agent}"
        else
            rm -f "$tmp"
            echo "skipped: ${agent}"
        fi
    done
