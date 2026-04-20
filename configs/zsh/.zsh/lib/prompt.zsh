#!/bin/zsh

# Show a startup banner via plx (kitty graphics protocol).
notify_shell_status() {
    if ! command -v plx &>/dev/null; then
        echo "Warning: plx not found; skipping banner." >&2
        return 1
    fi
    plx banner 2
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
    eval "$(plx init zsh)"
}
