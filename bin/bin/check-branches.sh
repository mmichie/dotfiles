#!/bin/bash
# This script lists branches without upstream along with their latest commit dates and checks if they were merged

set -euo pipefail

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "check-branches.sh: not inside a git repository"
    exit 1
fi

# Find branches without upstream. for-each-ref rather than `git branch -vv |
# grep`: the porcelain output marks the current branch with a leading "* ",
# which used to arrive here as a bare "*" and glob-expand to every file in the
# working directory. Tab-separated so the loop never has to split on spaces.
refs=$(git for-each-ref --format='%(refname:short)%09%(upstream:track)' refs/heads)

echo "Branches without upstream and their latest commit dates:"

# Iterate over each branch
while IFS=$'\t' read -r branch track; do
    [ "$track" = "[gone]" ] || continue

    # Trailing -- keeps a branch that shares its name with a path from being
    # read as a pathspec.
    latest_commit_date=$(git log -1 --format="%ci" "$branch" --)
    merged_commits=$(git log "$branch" --not --remotes -- | wc -l)

    echo "Branch: $branch"
    echo "Latest Commit Date: $latest_commit_date"

    if [ "$merged_commits" -eq 0 ]; then
        echo "Status: All commits are merged into remote branches"
    else
        echo "Status: Contains $merged_commits unmerged commits"
    fi

    echo
done <<<"$refs"
