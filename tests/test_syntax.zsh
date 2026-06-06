#!/usr/bin/env zsh
# Syntax sweep: every entry file, module, and autoloaded function must parse
# under `zsh -n`. Catches typos and bashisms that only blow up at source time.

source "${0:A:h}/lib.zsh"

typeset -a files
files=(
    "$ZSH_CONF"/.zshrc
    "$ZSH_CONF"/.zshenv
    "$ZSH_CONF"/.zprofile
    "$ZSH_CONF"/.zsh/lib/*.zsh(N)
    "$ZSH_CONF"/.zsh/functions/*(N.)
)

typeset f out
for f in "${files[@]}"; do
    if out=$(zsh --no-globalrcs -n "$f" 2>&1); then
        t_pass "parses: ${f#$REPO_ROOT/}"
    else
        t_fail "parses: ${f#$REPO_ROOT/}" "$out"
    fi
done

t_finish
