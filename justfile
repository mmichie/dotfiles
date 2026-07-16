# Dotfiles management via Nix

# Apply system configuration (detects host via `hostname -s` on Darwin/NixOS)
switch:
    @if [ "$(uname)" = "Darwin" ]; then \
        sudo "$(command -v darwin-rebuild)" switch --flake ".#$(hostname -s)" \
            && sudo "$(command -v nix-collect-garbage)" --delete-older-than 3d \
            && sudo "$(command -v nix-store)" --optimise; \
    elif [ -f /etc/NIXOS ] && [ -d "hosts/$(hostname -s)" ]; then \
        sudo "$(command -v nixos-rebuild)" switch --flake ".#$(hostname -s)"; \
    else \
        home-manager switch --flake .#mim@linux; \
    fi

# Install git hooks. The repo sets core.hooksPath globally (configs/git/
# .gitconfig), so git ignores .git/hooks and nothing wires lefthook in per
# clone. Run once per machine; also done automatically on `just switch` via a
# home-manager activation. --force: lefthook won't touch a global hooksPath.
hooks:
    lefthook install --force

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

# Check flake validity (builds checks.<current-system>, e.g. the zsh test
# suite). No --all-systems: nix would try to BUILD foreign-system checks and
# fail; host configs (darwin/nixos) are evaluated either way.
check:
    nix flake check

# Run the config test suite (also wired into lefthook, CI, and flake checks).
# --no-globalrcs keeps global zprofile/zshrc out of the runner; the global
# zshenv always runs regardless, but its set-environment PATH rewrite is
# already disarmed in interactive descendants (__NIX_DARWIN_SET_ENVIRONMENT_DONE).
test:
    zsh --no-globalrcs tests/run.zsh

# Show what would change
dry-run:
    @if [ "$(uname)" = "Darwin" ]; then \
        darwin-rebuild build --flake ".#$(hostname -s)" && nvd diff /run/current-system result; \
    elif [ -f /etc/NIXOS ] && [ -d "hosts/$(hostname -s)" ]; then \
        nixos-rebuild dry-activate --flake ".#$(hostname -s)"; \
    else \
        home-manager build --flake .#mim@linux; \
    fi

# Format all nix and lua files
fmt:
    nix fmt
    nix run nixpkgs#stylua -- configs/nvim

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

# Backup the sops age key, SSH keys, GPG keyring, and GAM runtime state to
# backup.tar.gz. The age key is the ROOT OF TRUST — without it the sops
# secrets (atuin, zshrc-local*) are undecryptable on a rebuild, so it leads.
# GAM's client_secrets.json + oauth2service.json are excluded: they come from
# 1Password (the gam wrapper re-pulls them). oauth2.txt (mutable token cache)
# and gam.cfg are machine-local state worth carrying; gamcache is regenerable.
# Store backup.tar.gz somewhere encrypted/offline — it holds private keys.
secrets-backup:
    tar -czvf backup.tar.gz \
        -C "$HOME" \
        --exclude='.gnupg/.#*' \
        --exclude='.gnupg/S.*' \
        --exclude='.gnupg/*.conf' \
        --exclude='.ssh/environment' \
        --exclude='.gam/gamcache' \
        --exclude='.gam/client_secrets.json' \
        --exclude='.gam/oauth2service.json' \
        --exclude='.gam/*.lock' \
        .config/sops/age/keys.txt \
        .ssh/ \
        .gnupg/ \
        .gam/

# Restore age key, SSH keys, GPG keyring, and GAM state from backup.tar.gz
secrets-restore:
    @[ -f backup.tar.gz ] || (echo "Error: backup.tar.gz not found"; exit 1)
    tar -xzvf backup.tar.gz -C "$HOME"
    chmod 700 "$HOME/.ssh" "$HOME/.gnupg"
    chmod 600 "$HOME/.ssh/"* || true
    [ -f "$HOME/.config/sops/age/keys.txt" ] && chmod 700 "$HOME/.config/sops/age" && chmod 600 "$HOME/.config/sops/age/keys.txt" || true
    [ -d "$HOME/.gam" ] && chmod 700 "$HOME/.gam" && chmod 600 "$HOME/.gam/oauth2.txt" 2>/dev/null || true

# Open nix repl with all flake outputs pre-loaded (configs, formatter, etc.)
repl:
    cd {{justfile_directory()}} && nix repl .

# Garbage collect old generations
gc:
    nix-collect-garbage -d

# Measure interactive zsh startup time. Runs N timed shells after a warmup,
# reports min/median/max, fails if median exceeds the budget (default 100ms;
# warm startup measures ~50ms, ~40ms once the /etc/zshrc promptinit +
# bashcompinit removal is switched in). Use `just profile 300` to override
# the budget, or `just profile-deep` for a zprof breakdown of where the
# time is spent.
profile budget_ms="100" runs="10":
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

# Measure COLD vs warm startup in a hermetic sandbox of the repo config
# (fresh HOME per cold run, so compinit + tool-init caches pay full price).
# Wall-clock stays local on purpose; the structural invariants behind these
# numbers are gated machine-independently in tests/test_performance.zsh.
profile-cold budget_ms="1000" runs="5":
    zsh tests/profile-cold.zsh {{budget_ms}} {{runs}}

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
