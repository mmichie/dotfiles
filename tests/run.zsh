#!/usr/bin/env zsh
# Run the zsh config test suite: every tests/test_*.zsh in its own process,
# all files concurrently. They are independent by construction (each owns a
# scratch HOME, tmux socket and agent stub), so each file's output is
# buffered and replayed under its header in name order, and the log reads
# exactly as the serial run did. Exit 0 iff every assertion in every file
# passed.
#
# Entry points that call this: `just test`, lefthook pre-commit (on changes
# under configs/zsh/ or tests/), the zsh-tests CI job, and the flake's
# checks.<system>.zsh-config derivation.
#
# Knobs: TEST_JOBS=N runs at most N files at a time (1 = serial, for chasing
# an interaction between files); TEST_TIMEOUT=S caps each file (default 120)
# when timeout(1) is available.

emulate -R zsh
typeset ROOT="${0:A:h}"
typeset -i failures=0
typeset -a files
files=("$ROOT"/test_*.zsh(N))
if (( ${#files} == 0 )); then
    print -r -- "run.zsh: no test files found in $ROOT" >&2
    exit 1
fi

# typeset f (bare, unassigned) would PRINT f=value for an inherited f rather
# than declare it — the same trap as the `p` that /etc/zshenv leaks.
typeset f=''
typeset -i rc max_jobs=${TEST_JOBS:-${#files}} timeout_s=${TEST_TIMEOUT:-120}
(( max_jobs >= 1 )) || max_jobs=1
typeset -a runner
runner=(zsh --no-globalrcs)
# Convert hangs into failures: a stuck boot (tty negotiation, a blocked
# read) would otherwise hang the suite — and CI with it.
(( $+commands[timeout] )) && runner=(timeout "$timeout_s" zsh --no-globalrcs)

typeset out
out="$(mktemp -d "${${TMPDIR:-/tmp}%/}/zsh-run.XXXXXXXX")" || exit 1
trap 'rm -rf "$out"' EXIT

# Launch in batches of $max_jobs. Each file writes its combined output and
# exit status under $out; a batch is collected before the next one starts.
# --no-globalrcs skips global zprofile/zshrc/zlogin. Note it does NOT skip
# the global zshenv (always sourced); the nix set-environment PATH rewrite
# there is disarmed via __NIX*_SET_ENVIRONMENT_DONE guards, exported by the
# flake check script and by _sandbox_env_args.
typeset -i i=0 running=0
for f in "${files[@]}"; do
    (( i++ ))
    {
        "${runner[@]}" "$f" > "$out/$i.log" 2>&1
        print -r -- $? > "$out/$i.rc"
    } &
    if (( ++running >= max_jobs )); then
        wait
        running=0
    fi
done
wait

i=0
for f in "${files[@]}"; do
    (( i++ ))
    print -r -- "-- ${f:t}"
    cat "$out/$i.log" 2>/dev/null
    rc=$(<"$out/$i.rc" 2>/dev/null)
    if [[ -z "$rc" ]]; then
        print -r -- "  not ok - ${f:t} produced no exit status"
        rc=1
    fi
    (( rc == 124 )) && print -r -- "  not ok - ${f:t} TIMED OUT after ${timeout_s}s"
    (( failures += rc ))
done

print
if (( failures )); then
    print -r -- "FAIL: $failures assertion(s) failed"
    exit 1
fi
print -r -- "PASS: all test files green"
