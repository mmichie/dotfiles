#!/bin/zsh

# Show a startup banner via chevron (kitty graphics protocol).
# CHEVRON_DISABLE covers this too: sandboxed/test shells must not run the
# renderer at all — it negotiates with the terminal, which is exactly the
# kind of side channel a captured boot cannot tolerate.
notify_shell_status() {
    [[ -n "$CHEVRON_DISABLE" ]] && return 0
    if ! command -v chevron &>/dev/null; then
        echo "Warning: chevron not found; skipping banner." >&2
        return 1
    fi
    chevron banner 2
}

# Percent-encode a path per RFC 3986 (unreserved + / pass through).
# Keeps OSC 7 URLs valid for paths with spaces or other specials.
_urlencode_path() {
    emulate -L zsh
    # Byte-wise, not character-wise: percent-encoding works on UTF-8 bytes
    # (é -> %C3%A9). Under a UTF-8 locale, $str[i] yields whole characters
    # and "'$c" the codepoint, producing invalid one-byte escapes.
    local LC_ALL=C
    local str="$1" out="" c i
    for (( i=1; i<=${#str}; i++ )); do
        c=${str[i]}
        if [[ $c == [A-Za-z0-9._~/-] ]]; then
            out+=$c
        else
            out+=$(printf '%%%02X' "'$c")
        fi
    done
    print -rn -- "$out"
}

# OSC 7 directory tracking
osc7_cwd() {
    local hostname=${HOST:-$(hostname)}
    printf '\e]7;file://%s%s\a' "$hostname" "$(_urlencode_path "$PWD")"
}

# Initialize prompt
init_prompt() {
    autoload -Uz add-zsh-hook
    add-zsh-hook precmd osc7_cwd
    # Kill switch for sandboxed shells (test suite, scripted boots): skip
    # chevron entirely — no daemon spawn, default prompt.
    [[ -n "$CHEVRON_DISABLE" ]] && return 0
    # No chevron (minimal box, CI) -> keep the default prompt quietly.
    command -v chevron &>/dev/null || return 0
    # Pre-spawn chevrond so the first prompt's daemon-query (CHEVRON_ASYNC)
    # and the live subscriber (CHEVRON_LIVE) catch the daemon before
    # falling through to inline compute. `chevron daemon start` is
    # non-blocking and idempotent: returns immediately if a daemon is
    # already running (locked via chevrond.lock), otherwise spawns
    # detached. Backgrounded (&!) so even its ~5ms fork is off the
    # startup critical path.
    chevron daemon start 2>/dev/null &!
    # `chevron init zsh` output is deterministic per binary — cache it like
    # the other tool inits instead of paying a fork+exec every shell.
    _init_from_cache "$SHELL_CACHE_DIR/chevron-init.zsh" \
        'chevron init zsh' "$commands[chevron]"
}

init_prompt
