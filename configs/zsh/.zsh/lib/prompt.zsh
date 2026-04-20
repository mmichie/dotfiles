#!/bin/zsh

# Show a startup banner via plx (kitty graphics protocol).
notify_shell_status() {
    if ! command -v plx &>/dev/null; then
        echo "Warning: plx not found; skipping banner." >&2
        return 1
    fi
    plx banner 2
}

# OSC 7 directory tracking
osc7_cwd() {
    local hostname=${HOST:-$(hostname)}
    local url="file://${hostname}${PWD}"
    printf '\e]7;%s\a' "${url}"
}

# Initialize prompt
init_prompt() {
    autoload -Uz add-zsh-hook
    add-zsh-hook precmd osc7_cwd
    eval "$(plx init zsh)"
}
