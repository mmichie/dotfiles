#!/usr/bin/env bash
# Rewrite git history to change author/committer name+email on commits
# where the email matches <old-email>.
#
# WARNING: this rewrites every commit hash. Coordinate with collaborators
# and make a backup before running. Operates on all branches and tags.

set -euo pipefail

usage() {
    cat >&2 <<EOF
Usage: $(basename "$0") <old-email> <new-email> <new-name>

  <old-email>  Email to match in existing commits (author or committer).
  <new-email>  Replacement email.
  <new-name>   Replacement name (quote if it contains spaces).

Example:
  $(basename "$0") old@example.com new@example.com "Matt Michie"
EOF
    exit 1
}

if [ "$#" -ne 3 ]; then
    usage
fi

OLD_EMAIL="$1"
NEW_EMAIL="$2"
NEW_NAME="$3"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "error: not inside a git repository" >&2
    exit 1
fi

repo_root=$(git rev-parse --show-toplevel)
match_count=$(git log --all --format='%ae%n%ce' | grep -cFx "$OLD_EMAIL" || true)

echo "Repository : $repo_root"
echo "Match      : $OLD_EMAIL"
echo "Replace w/ : $NEW_NAME <$NEW_EMAIL>"
echo "Affects    : $match_count commit entries (author or committer matches)"
echo

if [ "$match_count" -eq 0 ]; then
    echo "No commits match $OLD_EMAIL. Nothing to do."
    exit 0
fi

read -rp "Type 'rewrite' to proceed (this CANNOT be undone without a backup): " confirm
[ "$confirm" = "rewrite" ] || { echo "aborted"; exit 1; }

export FILTER_OLD_EMAIL="$OLD_EMAIL"
export FILTER_NEW_EMAIL="$NEW_EMAIL"
export FILTER_NEW_NAME="$NEW_NAME"

git filter-branch -f --env-filter '
    if [ "$GIT_COMMITTER_EMAIL" = "$FILTER_OLD_EMAIL" ]; then
        export GIT_COMMITTER_NAME="$FILTER_NEW_NAME"
        export GIT_COMMITTER_EMAIL="$FILTER_NEW_EMAIL"
    fi
    if [ "$GIT_AUTHOR_EMAIL" = "$FILTER_OLD_EMAIL" ]; then
        export GIT_AUTHOR_NAME="$FILTER_NEW_NAME"
        export GIT_AUTHOR_EMAIL="$FILTER_NEW_EMAIL"
    fi
' --tag-name-filter cat -- --branches --tags
