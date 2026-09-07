#!/usr/bin/env zsh
source "${0:A:h}/lib.zsh"
unsetopt bgnice

# Real interactive boots share a cache. Slow generators widen the race window;
# count rebuilds as well as checking every shell, not just a later warm boot.
typeset sb="$(make_sandbox_home)" n='' pid='' out=''
make_stub "$sb/tools-v1" fzf 'printf "init\n" >> "$HOME/tool-builds"
sleep 0.3
printf "typeset -g CACHE_TEST_VERSION=1\n"'
make_stub "$sb/tools-v2" fzf 'printf "init\n" >> "$HOME/tool-builds"
sleep 0.3
printf "typeset -g CACHE_TEST_VERSION=2\n"'
ln -s "$sb/tools-v1" "$sb/tools"
mkdir -p "$sb/extra-functions"
touch -t 200001010000 "$sb/extra-functions"
cat > "$sb/.zshrc.early.local" <<'EOF'
path=("$HOME/tools" $path)
fpath=("$HOME/extra-functions" $fpath)
autoload -Uz compinit
autoload +X compinit
functions[_test_real_compinit]=$functions[compinit]
compinit() {
    if [[ "$1" == -i ]]; then
        print -r -- rebuild >> "$HOME/comp-builds"
        sleep 0.3
    fi
    _test_real_compinit "$@"
}
EOF

run_wave() {
    local version="$1" phase="$2" n pid
    local -a pids
    for n in 1 2 3 4 5 6; do
        run_sandbox_zsh "$sb" 'print -r -- "READY=$CACHE_TEST_VERSION/${_comps[cd]}"' \
            > "$T_SCRATCH/$phase-$n.out" 2> "$T_SCRATCH/$phase-$n.err" &
        pids+=($!)
    done
    for pid in $pids; do
        wait "$pid" || t_fail "$phase child exits successfully"
    done
    for n in 1 2 3 4 5 6; do
        assert_contains "$(<"$T_SCRATCH/$phase-$n.out")" "READY=$version/_cd" "$phase shell $n loads valid caches"
        local -a noise=("${(@f)$(<"$T_SCRATCH/$phase-$n.err")}")
        noise=("${(@)noise:#*can?t change option: zle*}")
        assert_eq "${(F)noise}" '' "$phase shell $n has no cache errors"
    done
}
run_wave 1 cold
typeset -a builds=("${(@f)$(<"$sb/tool-builds")}")
assert_eq "${#builds}" 1 "concurrent cold shells generate tool cache once"
builds=("${(@f)$(<"$sb/comp-builds")}")
assert_eq "${#builds}" 1 "concurrent cold shells rebuild completion dump once"

# Switch the resolved binary path (Nix-style invalidation, independent of mtime).
command rm "$sb/tools"
ln -s "$sb/tools-v2" "$sb/tools"
run_wave 2 changed
builds=("${(@f)$(<"$sb/tool-builds")}")
assert_eq "${#builds}" 2 "concurrent shells regenerate changed tool cache once"
print -r -- '#compdef cache-race' > "$sb/extra-functions/_cache_race"
run_wave 2 completion
builds=("${(@f)$(<"$sb/comp-builds")}")
assert_eq "${#builds}" 2 "concurrent shells rebuild changed completion cache once"
out=$(run_sandbox_zsh "$sb" 'print -r -- "COMPLETER=${_comps[cache-race]}"' 2>/dev/null)
assert_contains "$out" 'COMPLETER=_cache_race' "new completion is registered after concurrent rebuild"
run_wave 2 warm
builds=("${(@f)$(<"$sb/tool-builds")}")
assert_eq "${#builds}" 2 "warm shells do not regenerate tool cache"
builds=("${(@f)$(<"$sb/comp-builds")}")
assert_eq "${#builds}" 2 "warm shells do not rebuild completion dump"

# A dead owner must never strand later shells, and a stuck owner must not
# block startup forever. Use an independent process (fcntl locks are per PID).
source "$ZSH_CONF/.zsh/lib/24-cache-lock.zsh"
typeset lockcache="$T_SCRATCH/owner-test" owner='' attempt_rc=0
cat > "$T_SCRATCH/owner.zsh" <<'EOF'
source "$1/.zsh/lib/24-cache-lock.zsh"
hold() {
    print -r -- ready > "$3"
    zmodload zsh/zselect
    zselect -t 3000
}
_with_cache_lock "$2" hold "$@"
EOF
zsh --no-globalrcs -f "$T_SCRATCH/owner.zsh" "$ZSH_CONF" "$lockcache" "$T_SCRATCH/ready" &
owner=$!
zmodload zsh/zselect
for n in {1..500}; do
    [[ -f "$T_SCRATCH/ready" ]] && break
    zselect -t 1
done
if [[ -f "$T_SCRATCH/ready" ]]; then
    out=$(_with_cache_lock "$lockcache" print -r -- UNLOCKED)
    attempt_rc=$?
    assert_eq "$attempt_rc" 75 "lock acquisition times out instead of hanging startup"
    assert_eq "$out" '' "timeout never invokes an unprotected cache operation"
else
    t_fail "lock owner acquired the lock before the contention probe"
fi
kill -KILL "$owner" 2>/dev/null
wait "$owner" 2>/dev/null
out=$(_with_cache_lock "$lockcache" print -r -- RECOVERED)
assert_eq "$out" RECOVERED "kernel releases the cache lock when its owner dies"
_lock_failure() { return 7; }
_with_cache_lock "$lockcache" _lock_failure
assert_eq "$?" 7 "cache transaction preserves an operation's failure status"
out=$(_with_cache_lock "$lockcache" print -r -- RELEASED)
assert_eq "$out" RELEASED "failed cache operation releases its lock"

t_finish
