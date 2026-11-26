#!/bin/zsh

# Show a startup banner via chevron: a card drawn as text (box characters in
# tmux's colours) with the machine's gauges, as wide as the terminal up to 80
# columns. CHEVRON_DISABLE covers this too: sandboxed and test shells run no
# chevron at all.
notify_shell_status() {
    [[ -n "$CHEVRON_DISABLE" ]] && return 0
    if ! command -v chevron &>/dev/null; then
        echo "Warning: chevron not found; skipping banner." >&2
        return 1
    fi
    chevron banner text
}

# Percent-encode a path per RFC 3986 (unreserved + / pass through).
# Keeps OSC 7 URLs valid for paths with spaces or other specials.
_urlencode_path() {
    local REPLY
    _urlencode_path_reply "$1"
    print -rn -- "$REPLY"
}

# Return through the caller's REPLY so precmd needs no command substitution.
_urlencode_path_reply() {
    emulate -L zsh
    # Byte-wise, not character-wise: percent-encoding works on UTF-8 bytes
    # (é -> %C3%A9). Under a UTF-8 locale, $str[i] yields whole characters
    # and "'$c" the codepoint, producing invalid one-byte escapes.
    local LC_ALL=C
    local str="$1" out="" c encoded i
    for (( i=1; i<=${#str}; i++ )); do
        c=${str[i]}
        if [[ $c == [A-Za-z0-9._~/-] ]]; then
            out+=$c
        else
            printf -v encoded '%%%02X' "'$c"
            out+="$encoded"
        fi
    done
    REPLY="$out"
}

# OSC 7 directory tracking
osc7_cwd() {
    local hostname=${HOST:-$(hostname)} REPLY
    _urlencode_path_reply "$PWD"
    printf '\e]7;file://%s%s\a' "$hostname" "$REPLY"
}

# st's window title, which dwm's bar shows. Inside tmux, tmux sets it from
# the window name (set-titles); outside, st has no shell integration to set
# it and keeps the command it was started with, so the shell does: the
# directory at the prompt, the command while one runs. (V) shows control
# characters as ^X instead of sending them to the terminal.
_st_title_precmd() {
    local dir='~'
    [[ $PWD == $HOME ]] || dir=${(V)${PWD:t}:-/}
    print -rn -- $'\e]2;'"$dir"$'\a'
}

_st_title_preexec() {
    local -a words=(${(z)1})
    print -rn -- $'\e]2;'"${(V)words[1]}"$'\a'
}

# dwm's chips for this terminal (hosts/vm-aarch64/dwm/chips.sh): its
# directory, git branch and status, and an agent's state, published in the
# background after each command where dwm-chips is installed (the VM).
# Inside tmux it updates every client's, as tmux's focus hooks do.
_dwm_chips_precmd() {
    if [[ -n $TMUX ]]; then
        dwm-chips --tmux "${TMUX%%,*}" >/dev/null 2>&1 &!
    else
        dwm-chips >/dev/null 2>&1 &!
    fi
}

# Initialize prompt
init_prompt() {
    autoload -Uz add-zsh-hook
    add-zsh-hook precmd osc7_cwd
    if [[ $TERM == st-* && -z $TMUX ]]; then
        add-zsh-hook precmd _st_title_precmd
        add-zsh-hook preexec _st_title_preexec
    fi
    if [[ -n $DISPLAY ]] && (( $+commands[dwm-chips] )); then
        add-zsh-hook precmd _dwm_chips_precmd
    fi
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
