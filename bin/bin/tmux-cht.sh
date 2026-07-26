#!/usr/bin/env bash

# tmux-cht.sh: Quick cheat sheet access using cht.sh
# Inspired by ThePrimeagen's workflow

selected=$(cat ~/.tmux-cht-languages ~/.tmux-cht-command 2>/dev/null | fzf)

if [[ -z $selected ]]; then
    exit 0
fi

read -rp "Enter Query: " query

# The selection and the query reach the new window as positional parameters
# instead of being spliced into the script text, so a quote or a ';' in either
# one is data rather than syntax. `set -f` stops a '*' from globbing; $1/$2 are
# left unquoted on purpose because cht.sh URLs were always built from the split
# words and curl rejects a URL containing a literal space.
# shellcheck disable=SC2016 # $1/$2 are for the inner shell to expand, not this one
if grep -qsF -- "$selected" ~/.tmux-cht-languages; then
    query=$(echo "$query" | tr ' ' '+')
    tmux neww bash -c 'set -f; echo "curl cht.sh/$1/$2/" & curl cht.sh/$1/$2 & while [ : ]; do sleep 1; done' bash "$selected" "$query"
else
    tmux neww bash -c 'set -f; curl -s cht.sh/$1~$2 | less -R' bash "$selected" "$query"
fi
