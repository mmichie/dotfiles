#!/bin/zsh

# Setup PATH environment variable
# Order = priority (first entry wins). typeset -U deduplicates.
setup_path() {
    typeset -U path

    # Go environment
    export GOPATH="${GOPATH:-$HOME/workspace/go}"
    export GOBIN="${GOBIN:-$GOPATH/bin}"
    export GOPROXY="${GOPROXY:-https://proxy.golang.org,direct}"

    path=(
        # User paths (highest priority)
        "$HOME/bin"
        "$HOME/.local/bin"
        "$HOME/.claude/local"

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

# Load environment variables from .env file
load_env_file() {
    local env_file="$1"
    [[ ! -f "$env_file" ]] && return 1

    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "$line" = \#* ]] && continue
        if [[ "$line" = [A-Za-z_]*([A-Za-z0-9_])=* ]]; then
            local cleaned_line="${line//\"/}"
            cleaned_line="${cleaned_line//\'/}"
            export "$cleaned_line"
        fi
    done < "$env_file"
}

# Main environment setup function
setup_environment() {
    # ── XDG directories ──────────────────────────────────────────
    export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
    export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
    export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
    export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

    # ── PATH ─────────────────────────────────────────────────────
    setup_path

    # ── Locale ───────────────────────────────────────────────────
    export LC_ALL="en_US.UTF-8"
    export LANG="en_US.UTF-8"
    export TZ="US/Pacific"

    # ── Editors ──────────────────────────────────────────────────
    if command -v nvim &>/dev/null; then
        export EDITOR="nvim"
        export VISUAL="nvim"
        alias vim='nvim'
        alias vi='nvim'
    else
        export EDITOR="vim -f"
        export VISUAL="vim -f"
    fi
    export P4EDITOR="$EDITOR"

    # ── Java (from nix) ──────────────────────────────────────────
    if command -v javac &>/dev/null; then
        export JAVA_HOME="$(dirname $(dirname $(readlink -f $(which javac))))"
    fi

    # ── Development ──────────────────────────────────────────────
    export PYTHONUNBUFFERED=1
    export FZF_DEFAULT_OPTS="--height 40% --border"
    export GCC_COLORS="error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01"
    is_linux && export NO_AT_BRIDGE=1

    # ── Terminal ─────────────────────────────────────────────────
    export COLORTERM="${COLORTERM:-truecolor}"
    export LESS="-R -F -X"
    export LESSHISTFILE="$XDG_CACHE_HOME/less/history"

    # ── Shell behavior ───────────────────────────────────────────
    export WORDCHARS='*?_-.[]~=&;!#$%^(){}<>'
    export TIMEFMT=$'\nreal\t%*E\nuser\t%*U\nsys\t%*S'
    export REPORTTIME=10
    export KEYTIMEOUT=1

    umask 022

    # ── Platform executables ─────────────────────────────────────
    if type setup_platform_executables &>/dev/null; then
        setup_platform_executables
    fi

    # ── Local overrides ──────────────────────────────────────────
    load_env_file "$HOME/.env"
}
