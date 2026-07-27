#!/bin/zsh
#
# .zshenv — sourced for EVERY zsh invocation (interactive, non-interactive,
# login, non-login, scripts). Keep this file fast and side-effect-free; it
# should only set environment that every shell (and every tmux run-shell,
# and every #() command in tmux status lines) legitimately needs.
#
# Interactive-only setup (aliases, prompt, keybindings) lives in .zshrc.

# Suppress the global compinit that Ubuntu's /etc/zsh/zshrc gates on this
# variable (zsh-common, /etc/zsh/zshrc:106-113). It is a bare compinit on top
# of the one .zshrc already runs, and it writes a second, unfingerprinted
# ~/.zcompdump beside the curated dump in ~/.cache/zsh. zsh reads ~/.zshenv
# before any global zshrc, so the guard is in place by the time that file
# runs. Unconditional: nothing reads it on macOS or NixOS, where the system
# layer drops the global compinit instead (modules/darwin/workstation-base.nix).
skip_global_compinit=1

# Setup PATH environment variable
# Order = priority (first entry wins). typeset -U deduplicates.
setup_path() {
    typeset -gU path

    # Go environment
    export GOPATH="${GOPATH:-$HOME/workspace/go}"
    export GOBIN="${GOBIN:-$GOPATH/bin}"
    export GOPROXY="${GOPROXY:-https://proxy.golang.org,direct}"

    path=(
        # User paths (highest priority)
        "$HOME/bin"
        "$HOME/.local/bin"

        # Nix profile paths
        "$HOME/.nix-profile/bin"
        "/etc/profiles/per-user/${USER}/bin"
        "/run/wrappers/bin"
        "/run/current-system/sw/bin"
        "/nix/var/nix/profiles/default/bin"

        # Language paths
        "$GOBIN"

        # Homebrew (macOS casks only — CLI tools come from nix)
        "/opt/homebrew/bin"
        "/opt/homebrew/sbin"

        # System
        "/usr/local/bin"
        "/usr/local/sbin"

        # Preserve existing entries
        $path
    )
}

setup_path

# Route chevron weather's location lookup through the Go CoreLocation bridge
# (macOS only; on other platforms chevron falls back to IP geolocation).
[[ "$OSTYPE" == darwin* ]] && export CHEVRON_WEATHER_LOCATION_CMD="wifi-location --latlon"
