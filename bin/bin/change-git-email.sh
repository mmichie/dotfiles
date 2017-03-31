#!/bin/sh

# from http://stackoverflow.com/questions/3042437/change-commit-author-at-one-specific-commit

git filter-branch --env-filter '

OLD_EMAIL="oldemail"
CORRECT_NAME="Matt Michie"
CORRECT_EMAIL="correctemail@"

if [ "$GIT_COMMITTER_EMAIL" = "$OLD_EMAIL" ]
then
    export GIT_COMMITTER_NAME="$CORRECT_NAME"
    export GIT_COMMITTER_EMAIL="$CORRECT_EMAIL"
fi
if [ "$GIT_AUTHOR_EMAIL" = "$OLD_EMAIL" ]
then
    export GIT_AUTHOR_NAME="$CORRECT_NAME"
    export GIT_AUTHOR_EMAIL="$CORRECT_EMAIL"
fi
' --tag-name-filter cat -- --branches --tags
