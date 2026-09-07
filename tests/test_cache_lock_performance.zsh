#!/usr/bin/env zsh
# Lock creation must not spawn an external true per integration. A hostile
# PATH stub makes that performance regression observable without timing gates.
source "${0:A:h}/lib.zsh"
typeset stubdir="$T_SCRATCH/bin" out=''
make_stub "$stubdir" true 'printf "external-true\n" >> "$TRUE_PROBE_LOG"; exit 9'
out=$(TRUE_PROBE_LOG="$T_SCRATCH/true.log" zsh --no-globalrcs -f -c '
    path=("$2")
    alias true="print -r -- ALIAS_EXPANDED"
    alias :="print -r -- ALIAS_EXPANDED"
    source "$1/.zsh/lib/24-cache-lock.zsh"
    _with_cache_lock "$3/probe" print -r -- LOCKED
    print -r -- "RC=$?"
' probe "$ZSH_CONF" "$stubdir" "$T_SCRATCH" 2>&1)
assert_eq "$out" $'LOCKED\nRC=0' "lock creation needs neither an external true nor user aliases"
if [[ -e "$T_SCRATCH/true.log" ]]; then
    t_fail "lock acquisition spawns no true process"
else
    t_pass "lock acquisition spawns no true process"
fi
t_finish
