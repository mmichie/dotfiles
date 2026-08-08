#!/usr/bin/env bash

# tmux-cht.sh: Quick cheat sheet access using cht.sh
# Inspired by ThePrimeagen's workflow

selected=$(cat ~/.tmux-cht-languages ~/.tmux-cht-command 2>/dev/null | fzf)

if [[ -z $selected ]]; then
    exit 0
fi

read -rp "Enter Query: " query
query=${query// /+}

# The selection and the query reach the new window as positional parameters
# instead of being spliced into the script text, so a quote or a ';' in either
# one is data rather than syntax. The assembled URL stays quoted so a multiword
# query remains one curl operand; spaces have already become cht.sh's `+` form.
# shellcheck disable=SC2016 # $1/$2 are for the inner shell to expand, not this one
if grep -qsFx -- "$selected" ~/.tmux-cht-languages; then
    tmux neww bash -c 'echo "curl cht.sh/$1/$2/" & curl -- "cht.sh/$1/$2/" & while [ : ]; do sleep 1; done' bash "$selected" "$query"
else
    tmux neww bash -c 'curl -s -- "cht.sh/$1~$2" | less -R' bash "$selected" "$query"
fi
