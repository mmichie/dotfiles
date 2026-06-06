#!/usr/bin/env zsh
# Cold vs warm startup timing against a hermetic sandbox of the repo config.
# Complements `just profile` (real environment, warm caches): each cold run
# boots a FRESH sandbox HOME, so compinit and every _refresh_cache tool init
# pay full price — something that cannot be measured against the real HOME
# without trashing its caches.
#
# Usage: zsh tests/profile-cold.zsh [budget_ms] [runs]
# Exit 1 if the cold median exceeds budget_ms (default 1000).
# Not named test_*.zsh on purpose: wall-clock numbers are machine-dependent
# and must stay out of CI — the structural invariants behind them are gated
# machine-independently in test_performance.zsh.

source "${0:A:h}/lib.zsh"
zmodload zsh/datetime

typeset -i budget=${1:-1000} runs=${2:-5}
typeset -F t0 t1
typeset -a cold warm
typeset -i i ms

typeset sb
for (( i = 1; i <= runs; i++ )); do
    sb="$(make_sandbox_home)"   # fresh HOME = guaranteed cold caches
    t0=$EPOCHREALTIME
    run_sandbox_zsh "$sb" 'exit' >/dev/null 2>&1
    t1=$EPOCHREALTIME
    (( ms = (t1 - t0) * 1000 ))   # assignment to integer var truncates
    cold+=( $ms )
done

# Warm runs reuse the last sandbox (caches already built).
for (( i = 1; i <= runs; i++ )); do
    t0=$EPOCHREALTIME
    run_sandbox_zsh "$sb" 'exit' >/dev/null 2>&1
    t1=$EPOCHREALTIME
    (( ms = (t1 - t0) * 1000 ))
    warm+=( $ms )
done

cold=(${(no)cold})
warm=(${(no)warm})
typeset -i cold_med=$cold[$(( runs / 2 + 1 ))] warm_med=$warm[$(( runs / 2 + 1 ))]

print -r -- "sandbox startup ($runs runs each):"
printf "  cold:  min %4d ms   median %4d ms   max %4d ms\n" $cold[1] $cold_med $cold[-1]
printf "  warm:  min %4d ms   median %4d ms   max %4d ms\n" $warm[1] $warm_med $warm[-1]
printf "  caching saves %d ms per cold start (budget %d ms)\n" $(( cold_med - warm_med )) $budget

if (( cold_med > budget )); then
    print -r -- "FAIL: cold median exceeds budget"
    exit 1
fi
print -r -- "OK"
