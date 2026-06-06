#!/usr/bin/env zsh
# Run the zsh config test suite: every tests/test_*.zsh in its own process.
# Exit 0 iff every assertion in every file passed.
#
# Entry points that call this: `just test`, lefthook pre-commit (on changes
# under configs/zsh/ or tests/), the zsh-tests CI job, and the flake's
# checks.<system>.zsh-config derivation.

emulate -R zsh
typeset ROOT="${0:A:h}"
typeset -i failures=0
typeset -a files
files=("$ROOT"/test_*.zsh(N))
if (( ${#files} == 0 )); then
    print -r -- "run.zsh: no test files found in $ROOT" >&2
    exit 1
fi

typeset f
typeset -i rc
for f in "${files[@]}"; do
    print -r -- "-- ${f:t}"
    # --no-globalrcs: without it, nix-darwin's /etc/zshenv rewrites the test
    # process's PATH (dropping store paths, appending /usr/bin), which then
    # leaks into every sandboxed shell the test spawns.
    zsh --no-globalrcs "$f"
    rc=$?
    (( failures += rc ))
done

print
if (( failures )); then
    print -r -- "FAIL: $failures assertion(s) failed"
    exit 1
fi
print -r -- "PASS: all test files green"
