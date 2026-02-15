#!/bin/bash
# Powerline-style path matching powerline-go:
# - First dir (home/root): bg:31, fg:15
# - Remaining dirs: bg:237, fg:254
# - Thin separators between remaining dirs
# - Thick arrows between color transitions

path="${PWD/#$HOME/~}"

# Split into components
IFS='/' read -ra parts <<< "$path"
n=${#parts[@]}

# Truncate to 5 components
if (( n > 5 )); then
    parts=("…" "${parts[@]:$((n-4))}")
    n=${#parts[@]}
fi

# Powerline characters (correct UTF-8 for private use area)
arrow=$'\xee\x82\xb0'    # U+E0B0
thin=$'\xee\x82\xb1'     # U+E0B1

# ANSI helpers
ESC=$'\033'
fg() { printf '%s' "${ESC}[38;5;${1}m"; }
bg() { printf '%s' "${ESC}[48;5;${1}m"; }

out=""

if (( n == 1 )); then
    # Single component on bg:31, then transition to bg:237 for consistency
    out+="$(fg 238)$(bg 31)${arrow} $(fg 15)${parts[0]} $(fg 31)$(bg 237)${arrow} "
else
    # First component on bg:31 (blue)
    out+="$(fg 238)$(bg 31)${arrow} $(fg 15)${parts[0]} "

    # Arrow from first(31) to rest(237)
    out+="$(fg 31)$(bg 237)${arrow}"

    # Remaining components on bg:237
    for (( i=1; i<n; i++ )); do
        if (( i > 1 )); then
            out+=" $(fg 245)${thin}"
        fi
        out+=" $(fg 254)${parts[$i]}"
    done
    out+=" "
fi

printf '%s' "$out"
