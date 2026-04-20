#!/bin/bash
# Claude Code status line — mirrors plx/starship prompt style
# Displays: user@host  cwd  git-branch  model  context%

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')

# Shorten home directory to ~
home_dir="$HOME"
short_cwd="${cwd/#$home_dir/\~}"

# Git branch (skip optional lock to avoid hanging)
git_branch=""
if git -C "$cwd" rev-parse --is-inside-work-tree &>/dev/null 2>&1; then
    git_branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null ||
        git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
fi

# Build the status line
user_host="$(whoami)@$(hostname -s)"

parts="${user_host}  ${short_cwd}"
[ -n "$git_branch" ] && parts="${parts}  ${git_branch}"
[ -n "$model" ] && parts="${parts}  ${model}"
[ -n "$remaining" ] && parts="${parts}  ctx:$(printf '%.0f' "$remaining")%"

printf "%s" "$parts"
