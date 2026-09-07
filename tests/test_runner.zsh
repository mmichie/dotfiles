#!/usr/bin/env zsh
# The runner itself (tests/run.zsh), driven over a scratch directory of fake
# test files through a copy of the script (it discovers test_*.zsh next to
# itself). Pinned:
#   - any failing file makes the run exit 1; the summary carries the count
#   - output is replayed per file, in name order, each under its header
#   - files run concurrently: two files sleeping 2s finish in well under 4s
#   - TEST_JOBS=1 restores serial execution (the two sleeps take >= 4s)
#   - TEST_TIMEOUT cuts a hung file off: status 124 and a TIMED OUT line

source "${0:A:h}/lib.zsh"
zmodload zsh/datetime

typeset fake="$T_SCRATCH/fake"
mkdir -p "$fake"
cp "$T_LIB_DIR/run.zsh" "$fake/run.zsh"
print -r -- 'print -r -- "  ok - a"; exit 0' > "$fake/test_a.zsh"
print -r -- 'print -r -- "  not ok - b1"; print -r -- "  not ok - b2"; exit 2' > "$fake/test_b.zsh"
print -r -- 'sleep 2; print -r -- "  ok - c slept"; exit 0' > "$fake/test_c.zsh"
print -r -- 'sleep 2; print -r -- "  ok - d slept"; exit 0' > "$fake/test_d.zsh"

# run_fake [VAR=val ...]: run the copied runner with a clean knob environment;
# leaves RUN_OUT, RUN_RC, RUN_ELAPSED.
typeset RUN_OUT='' RUN_ELAPSED=''
typeset -i RUN_RC=0
run_fake() {
    local dir="$1"; shift
    local t0=$EPOCHREALTIME
    RUN_OUT="$(env -u TEST_JOBS -u TEST_TIMEOUT "$@" zsh --no-globalrcs "$dir/run.zsh" 2>&1)"
    RUN_RC=$?
    RUN_ELAPSED=$(( EPOCHREALTIME - t0 ))
}

# Position of a literal needle in RUN_OUT (0 = absent), for order checks.
pos() { print -r -- "${${RUN_OUT%%"$1"*}:+${#${RUN_OUT%%"$1"*}}}"; }
in_order() {   # in_order needle1 needle2 ... : each appears after the previous
    local prev=-1 p
    for n in "$@"; do
        [[ "$RUN_OUT" == *"$n"* ]] || return 1
        p=${#${RUN_OUT%%"$n"*}}
        (( p > prev )) || return 1
        prev=$p
    done
    return 0
}

run_fake "$fake"
assert_eq "$RUN_RC" "1" "any failing file makes the run exit 1"
assert_contains "$RUN_OUT" "FAIL: 2 assertion(s) failed" "summary line reports the failure count"
if in_order "-- test_a.zsh" "  ok - a" "-- test_b.zsh" "  not ok - b1" "  not ok - b2" "-- test_c.zsh" "  ok - c slept" "-- test_d.zsh" "  ok - d slept"; then
    t_pass "output is replayed per file in name order"
else
    t_fail "output is replayed per file in name order" "${RUN_OUT//$'\n'/ | }"
fi
if (( RUN_ELAPSED < 3.5 )); then
    t_pass "files run concurrently (two 2s sleeps finished in ${RUN_ELAPSED%.*}s)"
else
    t_fail "files run concurrently (two 2s sleeps finished in ${RUN_ELAPSED%.*}s)" "expected < 3.5s; the serial runner needs >= 4s"
fi

run_fake "$fake" TEST_JOBS=1
assert_eq "$RUN_RC" "1" "TEST_JOBS=1 keeps the exit status"
if (( RUN_ELAPSED >= 4.0 )); then
    t_pass "TEST_JOBS=1 runs files serially (${RUN_ELAPSED%.*}s for two 2s sleeps)"
else
    t_fail "TEST_JOBS=1 runs files serially (${RUN_ELAPSED%.*}s for two 2s sleeps)" "expected >= 4s"
fi

if have timeout; then
    typeset hung="$T_SCRATCH/hung"
    mkdir -p "$hung"
    cp "$T_LIB_DIR/run.zsh" "$hung/run.zsh"
    print -r -- 'print -r -- "  ok - fast"; exit 0' > "$hung/test_fast.zsh"
    print -r -- 'sleep 8; exit 0' > "$hung/test_hung.zsh"
    # The outer timeout bounds a runner that ignores TEST_TIMEOUT (the old
    # one waited 120s); a working runner returns in about a second.
    run_fake "$hung" TEST_TIMEOUT=1 timeout 6
    assert_eq "$RUN_RC" "1" "a hung file fails the run"
    if (( RUN_ELAPSED < 5 )); then
        t_pass "the run returns at TEST_TIMEOUT, not at the hung file's own duration (${RUN_ELAPSED%.*}s)"
    else
        t_fail "the run returns at TEST_TIMEOUT, not at the hung file's own duration (${RUN_ELAPSED%.*}s)" "expected < 5s"
    fi
    assert_contains "$RUN_OUT" "TIMED OUT after 1s" "the cut-off file gets a TIMED OUT line"
    assert_contains "$RUN_OUT" "  ok - fast" "other files still report"
else
    t_skip "TEST_TIMEOUT cuts off a hung file" "timeout(1) not in PATH"
fi

t_finish
