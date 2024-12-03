#!/bin/bash
# This script lists branches without upstream along with their latest commit dates and checks if they were merged

# Find branches without upstream
branches=$(git branch -vv | grep ': gone]' | awk '{print $1}')

echo "Branches without upstream and their latest commit dates:"

# Iterate over each branch
for branch in $branches; do
    latest_commit_date=$(git log -1 --format="%ci" $branch)
    merged_commits=$(git log $branch --not --remotes | wc -l)

    echo "Branch: $branch"
    echo "Latest Commit Date: $latest_commit_date"

    if [ $merged_commits -eq 0 ]; then
        echo "Status: All commits are merged into remote branches"
    else
        echo "Status: Contains $merged_commits unmerged commits"
    fi

    echo
done

