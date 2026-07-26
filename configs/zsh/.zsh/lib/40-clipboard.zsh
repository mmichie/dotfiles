#!/bin/zsh

# Cross-platform clipcopy/clippaste — detect-once stubs.
# Adapted from oh-my-zsh's lib/clipboard.zsh. The first call to either name
# unfunctions the stubs, runs detect-clipboard (which installs real functions
# for the detected backend), and re-dispatches.
#
# The `command` prefixes below are load-bearing: these bodies are PARSED at
# source time, with 30-aliases.zsh's aliases already in effect, so a bare
# `cat` was stored as `bat --style=plain --paging=never --wrap=never ...`.
# Clipboard bytes then rest on bat's "behave like cat when stdout is not a
# tty" fallback (it does today, byte for byte) and pay a bat fork per copy —
# neither is something a clipboard primitive should depend on.
# pbcopy/pbpaste are aliased to clipcopy/clippaste at the foot of this very
# file on non-darwin platforms, where a `source ~/.zshrc` reload would then
# parse the darwin bodies into self-recursion — unreachable today only
# because that branch needs darwin. Rule for new backends: any name this
# file or 30-aliases.zsh also aliases needs the prefix.

detect-clipboard() {
    emulate -L zsh

    if [[ "${OSTYPE}" == darwin* ]] && (( ${+commands[pbcopy]} )) && (( ${+commands[pbpaste]} )); then
        clipcopy() { command cat "${1:-/dev/stdin}" | command pbcopy; }
        clippaste() { command pbpaste; }
    elif (( ${+commands[clip.exe]} )) && (( ${+commands[powershell.exe]} )); then
        clipcopy() { command cat "${1:-/dev/stdin}" | clip.exe; }
        clippaste() { powershell.exe -noprofile -command Get-Clipboard; }
    elif [[ -n "${WAYLAND_DISPLAY:-}" ]] && (( ${+commands[wl-copy]} )) && (( ${+commands[wl-paste]} )); then
        clipcopy() { command cat "${1:-/dev/stdin}" | wl-copy &>/dev/null &|; }
        clippaste() { wl-paste --no-newline; }
    elif [[ -n "${DISPLAY:-}" ]] && (( ${+commands[xsel]} )); then
        clipcopy() { command cat "${1:-/dev/stdin}" | xsel --clipboard --input; }
        clippaste() { xsel --clipboard --output; }
    elif [[ -n "${DISPLAY:-}" ]] && (( ${+commands[xclip]} )); then
        clipcopy() { command cat "${1:-/dev/stdin}" | xclip -selection clipboard -in &>/dev/null &|; }
        clippaste() { xclip -out -selection clipboard; }
    elif [[ -n "${TMUX:-}" ]] && (( ${+commands[tmux]} )); then
        clipcopy() { tmux load-buffer -w "${1:--}"; }
        clippaste() { tmux save-buffer -; }
    else
        clipcopy() { print "clipcopy: no clipboard backend found on $OSTYPE" >&2; return 1; }
        clippaste() { print "clippaste: no clipboard backend found on $OSTYPE" >&2; return 1; }
    fi
}

# Stubs: $0 is the invoked name (clipcopy or clippaste).
function clipcopy clippaste {
    unfunction clipcopy clippaste
    detect-clipboard
    "$0" "$@"
}

# Muscle-memory aliases. pbcopy/pbpaste are real binaries on macOS, so only
# alias them on other platforms.
[[ "${OSTYPE}" == darwin* ]] || {
    alias pbcopy=clipcopy
    alias pbpaste=clippaste
}
alias clip=clipcopy
