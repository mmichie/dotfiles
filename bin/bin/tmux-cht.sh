#!/usr/bin/env bash

# tmux-cht.sh: Quick cheat sheet access using cht.sh
# Inspired by ThePrimeagen's workflow

selected=$(cat ~/.tmux-cht-languages ~/.tmux-cht-command 2>/dev/null | fzf)

if [[ -z $selected ]]; then
    exit 0
fi

read -p "Enter Query: " query

if grep -qs "$selected" ~/.tmux-cht-languages; then
    query=$(echo $query | tr ' ' '+')
    tmux neww bash -c "echo \"curl cht.sh/$selected/$query/\" & curl cht.sh/$selected/$query & while [ : ]; do sleep 1; done"
else
    tmux neww bash -c "curl -s cht.sh/$selected~$query | less -R"
fi
