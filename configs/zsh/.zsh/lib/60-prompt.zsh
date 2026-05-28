#!/bin/zsh

# Show a startup banner via chevron (kitty graphics protocol).
notify_shell_status() {
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
    # Pre-spawn chevrond so the first prompt's daemon-query (CHEVRON_ASYNC)
    # and the live subscriber (CHEVRON_LIVE) catch the daemon before
    # falling through to inline compute. `chevron daemon start` is
    # non-blocking and idempotent: returns immediately if a daemon is
    # already running (locked via chevrond.lock), otherwise spawns
    # detached. ~5ms one-time cost on the first shell of the boot.
    command -v chevron &>/dev/null && chevron daemon start 2>/dev/null
    eval "$(chevron init zsh)"
}

init_prompt
