#!/bin/bash
# Complete git status with colored powerline segments for starship
# Outputs ANSI-colored text with proper arrow transitions between segments
# Optimized: uses git status --porcelain=v2 --branch for single git call

# Get git dir (needed for state check, also validates we're in a repo)
git_dir=$(git rev-parse --git-dir 2>/dev/null) || exit 0

# Single command for branch, ahead/behind, and file status
staged=0 modified=0 untracked=0 conflicted=0 ahead=0 behind=0 branch=""

while IFS= read -r line; do
    case "$line" in
        "# branch.head "*)
            branch="${line#\# branch.head }"
            ;;
        "# branch.ab "*)
            read -r _ _ a b <<< "$line"
            ahead="${a#+}" ; behind="${b#-}"
            ;;
        "? "*) ((untracked++)) ;;
        "u "*) ((conflicted++)) ;;
        "1 "* | "2 "*)
            [[ "${line:2:1}" != "." ]] && ((staged++))
            [[ "${line:3:1}" != "." ]] && ((modified++))
            ;;
    esac
done < <(git status --porcelain=v2 --branch 2>/dev/null)

# Handle detached HEAD
[[ "$branch" == "(detached)" ]] && branch=$(git rev-parse --short HEAD 2>/dev/null)

# Stash count (only check if stash ref exists)
stashed=0
if [[ -f "$git_dir/refs/stash" ]]; then
    stashed=$(git stash list 2>/dev/null | wc -l)
    stashed="${stashed// /}"
fi

# Git state (filesystem checks, no git commands)
state=""
if [[ -d "$git_dir/rebase-merge" || -d "$git_dir/rebase-apply" ]]; then
    state="REBASING"
elif [[ -f "$git_dir/MERGE_HEAD" ]]; then
    state="MERGING"
elif [[ -f "$git_dir/CHERRY_PICK_HEAD" ]]; then
    state="CHERRY"
elif [[ -f "$git_dir/BISECT_LOG" ]]; then
    state="BISECT"
fi

# Powerline characters (UTF-8 byte sequences)
arrow=$'\xee\x82\xb0'        # U+E0B0
branch_icon=$'\xee\x82\xa0'  # U+E0A0

# ANSI color helpers
ESC=$'\033'
fg() { printf '%s' "${ESC}[38;5;${1}m"; }
bg() { printf '%s' "${ESC}[48;5;${1}m"; }
rst="${ESC}[0m"

# Determine if dirty
dirty=0
(( staged + modified + untracked + conflicted + stashed + ahead + behind > 0 )) && dirty=1
[[ -n "$state" ]] && dirty=1

out=""

if (( dirty )); then
    # Pink branch: arrow from path (237) to 161
    out+="$(fg 237)$(bg 161)${arrow} $(fg 15)${branch_icon} ${branch} "
    prev=161

    # Git state
    if [[ -n "$state" ]]; then
        out+="$(fg $prev)$(bg 220)${arrow} $(fg 0)${state} "
        prev=220
    fi

    # Status segments with powerline-go colors
    segs=()
    (( ahead > 0 )) && segs+=("240:${ahead}⬆")
    (( behind > 0 )) && segs+=("240:${behind}⬇")
    (( staged > 0 )) && segs+=("22:${staged}✔")
    (( modified > 0 )) && segs+=("130:${modified}✎")
    (( untracked > 0 )) && segs+=("52:${untracked}+")
    (( conflicted > 0 )) && segs+=("9:${conflicted}✼")
    (( stashed > 0 )) && segs+=("20:${stashed}⚑")

    for seg in "${segs[@]}"; do
        seg_bg="${seg%%:*}"
        seg_text="${seg#*:}"
        out+="$(fg $prev)$(bg $seg_bg)${arrow} $(fg 15)${seg_text} "
        prev=$seg_bg
    done

    # Final arrow to terminal bg (236)
    out+="$(fg $prev)$(bg 236)${arrow}${rst}"
else
    # Green branch (clean): arrow from path (237) to 148
    out+="$(fg 237)$(bg 148)${arrow} $(fg 0)${branch_icon} ${branch} "
    out+="$(fg 148)$(bg 236)${arrow}${rst}"
fi

printf '%s' "$out"
