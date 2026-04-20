#!/bin/zsh

# setup_path lives in .zshenv so it fires for every zsh (including the
# non-interactive ones spawned by tmux run-shell). The call at .zshrc:174
# re-runs it after macOS's path_helper reorders PATH for login shells.

# Parse a .env file and export its vars. Second arg (optional): set to 1
# to echo each loaded var name. Strips a single matching pair of outer
# quotes (double or single) from values; preserves quotes elsewhere.
_parse_env_file() {
    local env_file="$1" verbose="${2:-0}"
    [[ -f "$env_file" ]] || return 1

    local line key value
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ -z "$line" || "$line" = \#* ]] && continue
        [[ "$line" = [A-Za-z_]*([A-Za-z0-9_])=* ]] || continue

        key="${line%%=*}"
        value="${line#*=}"

        case "$value" in
            \"*\") value="${value#\"}"; value="${value%\"}" ;;
            \'*\') value="${value#\'}"; value="${value%\'}" ;;
        esac

        export "$key=$value"
        (( verbose )) && echo "Loaded: $key"
    done < "$env_file"
}

# Main environment setup function
setup_environment() {
    # ── XDG directories ──────────────────────────────────────────
    export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
    export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
    export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
    export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

    # PATH is handled in .zshenv (runs for every zsh); this function is
    # called only from interactive .zshrc which needs the post-path_helper
    # re-apply on macOS login — that's done directly in .zshrc.

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
    # Lazy: compute JAVA_HOME on first reference instead of every shell start
    # (the resolve-javac subshell chain was 4-5ms). First `java` / `javac` /
    # `gradle` / etc. invocation triggers the real export; subsequent calls
    # see the populated env.
    local _cmd
    for _cmd in java javac gradle mvn sbt; do
        eval "$_cmd() { _java_home_lazy; unfunction java javac gradle mvn sbt 2>/dev/null; command $_cmd \"\$@\"; }"
    done
    _java_home_lazy() {
        local javac_bin
        javac_bin=$(command -v javac 2>/dev/null) || return
        javac_bin=${javac_bin:A}  # zsh :A = absolute + resolve symlinks
        export JAVA_HOME="${javac_bin:h:h}"
    }

    # ── Claude Code ──────────────────────────────────────────────
    export CLAUDE_CODE_EFFORT_LEVEL="max"

    # ── Development ──────────────────────────────────────────────
    export PYTHONUNBUFFERED=1
    export FZF_DEFAULT_OPTS="--height 40% --border"
    export GCC_COLORS="error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01"
    is_linux && export NO_AT_BRIDGE=1

    # ── Tmux nesting ──────────────────────────────────────────────
    # Shells inside tmux export TMUX_LEVEL so a nested tmux server
    # can detect it at startup and apply different styling.
    [[ -n "$TMUX" ]] && export TMUX_LEVEL=1

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
    _parse_env_file "$HOME/.env"
}
