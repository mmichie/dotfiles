#!/bin/zsh

# setup_path lives in .zshenv so it fires for every zsh (including the
# non-interactive ones spawned by tmux run-shell). .zprofile re-runs it for
# login shells after macOS's path_helper has reordered PATH.

# Parse a .env file and export its vars. Second arg (optional): set to 1
# to echo each loaded var name. Strips a single matching pair of outer
# quotes (double or single) from values; preserves quotes elsewhere.
_parse_env_file() {
    [[ -f "$1" ]] || return 1

    # Keep the input line and value in $3 and $4 so imported keys cannot
    # overwrite parser locals or disappear when the function returns.
    set -- "$1" "${2:-0}" '' ''
    while IFS= read -r 'argv[3]' || [[ -n "$3" ]]; do
        # CRLF tolerance: a .env written on Windows (or by a CRLF-happy
        # editor) would otherwise export values with a trailing \r.
        argv[3]="${3%$'\r'}"
        [[ -z "$3" || "$3" = \#* ]] && continue
        # Valid identifier then `=`. `#` (zero or more, EXTENDED_GLOB) — the
        # ksh-style `*(...)` this replaced means something else in zsh and
        # rejected single-char keys while passing names like FOO-BAR.
        [[ "$3" = [A-Za-z_][A-Za-z0-9_]#=* ]] || continue

        argv[4]="${3#*=}"

        case "$4" in
            \"*\") argv[4]="${${4#\"}%\"}" ;;
            \'*\') argv[4]="${${4#\'}%\'}" ;;
        esac

        export "${3%%=*}=$4" || return
        if (( $2 )); then
            print -r -- "Loaded: ${3%%=*}"
        fi
    done < "$1" || return
    return 0
}

# Personal time zone only where the system has none: UTC servers and
# containers without /etc/localtime. A machine with a real local zone keeps
# it (macOS follows location; the VM sets its own), so shell timestamps
# and git offsets agree with the clock wherever the laptop is. The path is
# a parameter for the test suite. :A resolves the symlink without a fork;
# only the resolved basename is inspected. A copied (non-symlink) zone file
# cannot be classified and keeps the system zone.
_setup_timezone() {
    local localtime="${1:-/etc/localtime}"
    if [[ ! -e "$localtime" ]]; then
        export TZ="America/Los_Angeles"
        return
    fi
    case "${localtime:A:t}" in
        UTC|UCT|Universal|Zulu|GMT) export TZ="America/Los_Angeles" ;;
    esac
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
    # LANG only, never LC_ALL: LC_ALL overrides every LC_* category, so
    # exporting it made any downstream per-category setting (LC_COLLATE=C
    # for byte-order sort, LC_TIME) a silent no-op. Functions that need C
    # byte semantics set a local LC_ALL themselves.
    export LANG="en_US.UTF-8"
    _setup_timezone

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
        # Respect a JDK selected by the user or a project environment.
        [[ -n "$JAVA_HOME" ]] && return 0
        # whence -p: path search only. `command -v javac` would return the
        # lazy wrapper *function* name (it's still defined at this point),
        # which :A would then resolve relative to $PWD — garbage JAVA_HOME.
        local javac_bin
        javac_bin=$(whence -p javac 2>/dev/null) || return
        javac_bin=${javac_bin:A}  # zsh :A = absolute + resolve symlinks
        export JAVA_HOME="${javac_bin:h:h}"
    }

    # ── Claude Code ──────────────────────────────────────────────
    export CLAUDE_CODE_EFFORT_LEVEL="max"

    # ── Chevron (daily-drive opt-ins) ────────────────────────────
    # CHEVRON_HISTORY=1 (default): preexec/precmd publish command-
    #   lifecycle events to chevrond → SQLite commands log.
    #   `chevron history --grep 'cargo test'` to query.
    # CHEVRON_LIVE=1: chevrond push events (.git changes + cmd-end)
    #   redraw the prompt without keystroke — branch indicator
    #   updates after a background `git fetch`, command finished
    #   in another pane, etc.
    # CHEVRON_ASYNC=1: stale-then-fresh prompt — render cached
    #   prompt immediately, spawn background re-render, redraw via
    #   zle reset-prompt when fresh data lands. Zero perceived
    #   latency on the keystroke hot path.
    # Output capture (per-command): `chcap <cmd>` alias wraps a
    #   command in PTY interposition; bytes land in
    #   $XDG_RUNTIME_DIR/chevron/outputs/<ulid>.log. Search via
    #   `chevron history --grep-output PATTERN` / replay via
    #   `chevron history --show-output <id>`.
    export CHEVRON_HISTORY=1
    export CHEVRON_LIVE=1
    export CHEVRON_ASYNC=1

    # ── Development ──────────────────────────────────────────────
    export PYTHONUNBUFFERED=1
    export FZF_DEFAULT_OPTS="--height 40% --border"
    export GCC_COLORS="error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01"
    is_linux && export NO_AT_BRIDGE=1
    is_osx && has_capability "homebrew" && export HOMEBREW_NO_ANALYTICS=1

    # ── Tmux nesting ──────────────────────────────────────────────
    # Shells inside tmux export TMUX_LEVEL so a nested tmux server
    # can detect it at startup and apply different styling.
    [[ -n "$TMUX" ]] && export TMUX_LEVEL=1

    # ── Terminal ─────────────────────────────────────────────────
    export COLORTERM="${COLORTERM:-truecolor}"
    export LESS="-R -F -X"
    export LESSHISTFILE="$XDG_CACHE_HOME/less/history"
    # less does not create missing parent directories: without this one it
    # skips the write and no history is ever saved. One stat per shell; the
    # mkdir runs once per machine.
    [[ -d "${LESSHISTFILE:h}" ]] || command mkdir -p "${LESSHISTFILE:h}"

    # ── Shell behavior ───────────────────────────────────────────
    # typeset -g +x, not export: these tune THIS interactive shell. Exported,
    # every zsh it starts inherits them, and with REPORTTIME in its
    # environment a non-interactive zsh prints a timing block after any
    # command that used more than 10 CPU seconds. +x also strips the flag
    # when it was inherited from a pre-fix parent (tmux server, old shells).
    typeset -g +x WORDCHARS='*?_-.[]~=&;!#$%^(){}<>'
    typeset -g +x TIMEFMT=$'\nreal\t%*E\nuser\t%*U\nsys\t%*S'
    typeset -g +x REPORTTIME=10
    typeset -g +x KEYTIMEOUT=1

    umask 022

    # ── Local overrides ──────────────────────────────────────────
    _parse_env_file "$HOME/.env"
}

setup_environment
