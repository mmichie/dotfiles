#!/usr/bin/env zsh
source "${0:A:h}/lib.zsh"

typeset stubdir="$T_SCRATCH/bin" cache_dir="$T_SCRATCH/cache" out='' inner="$T_SCRATCH/probe.zsh"
make_stub "$stubdir" fzf 'printf "INVOKED\n" >> "$HOME/doctor-tool-called"'
mkdir -p "$cache_dir"
cat > "$inner" <<'EOF'
source "$1/.zsh/functions/shell-doctor"
SHELL_CACHE_DIR="$2"
remove="${commands[rm]}" touch_bin="${commands[touch]}"
path=("$3")
cache="$2/fzf-init.zsh"
typeset -A _SHELL_INIT_STATUS _SHELL_INIT_COMMAND _comps
_SHELL_INIT_STATUS[$cache]=0
_SHELL_INIT_COMMAND[$cache]='fzf --zsh'
print -r -- 'print -r -- PRIVATE_CACHE_CONTENT' > "$cache"
print -rl -- 'fzf --zsh' "${3:A}/fzf" > "$cache.dep"
_comps[cd]=_cd
zmodload -F zsh/stat b:zstat
stamps=()
for item in $fpath; do
    zstat -A mtimes +mtime -- "$item" 2>/dev/null || mtimes=(none)
    stamps+=("${item:A}:$mtimes[1]")
done
print -r -- dump > "$2/.zcompdump"
print -r -- "${(F)stamps}" > "$2/.zcompdump.fpath"
# Mark the cache as loaded, but never execute its contents in the doctor.
case "$4" in
    stale) print -rl -- 'fzf --zsh' '/old-generation/fzf' > "$cache.dep" ;;
    command) _SHELL_INIT_COMMAND[$cache]='fzf --new-option' ;;
    unloaded) unset _SHELL_INIT_STATUS; typeset -A _SHELL_INIT_STATUS ;;
    missing) "$remove" "$cache" ;;
    metadata) "$remove" "$cache.dep" ;;
    modified) "$touch_bin" -t 200001010000 "$cache" ;;
    failed) _SHELL_INIT_STATUS[$cache]=75 ;;
    minimal) ZSH_MINIMAL=1 ;;
    busy|compbusy)
        zmodload zsh/system
        lock="$2/.cache-lock-fzf-init.zsh"
        [[ "$4" == compbusy ]] && lock="$2/.cache-lock-.zcompdump"
        print -rn -- '' > "$lock"
        zsystem flock -f held "$lock"
        ;;
    insecure)
        fpath=("$5" $fpath)
        ;;
esac
typeset before_functions="${(ok)functions}" before_options="${(kv)options}"
shell-doctor
print -r -- "DOCTOR_RC=$?"
[[ "$before_functions" == "${(ok)functions}" && "$before_options" == "${(kv)options}" ]] && print -r -- STATE_UNCHANGED
if [[ -n "$held" ]]; then
    zsystem flock -u "$held"
    "$remove" "$lock"
fi
EOF

typeset mode='' home="$T_SCRATCH/home" insecure="$T_SCRATCH/insecure"
mkdir -p "$home" "$insecure"
print -r -- '#compdef doctor-test' > "$insecure/_doctor_test"
chmod 777 "$insecure"
for mode in normal stale command unloaded missing metadata modified failed minimal insecure busy compbusy; do
    out=$(HOME="$home" zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$cache_dir" "$stubdir" "$mode" "$insecure" 2>&1)
    assert_contains "$out" STATE_UNCHANGED "$mode diagnosis preserves caller functions and options"
    assert_not_contains "$out" PRIVATE_CACHE_CONTENT "$mode diagnosis never executes or prints cache contents"
    case "$mode" in
        normal)
            assert_contains "$out" "$stubdir/fzf; loaded" "reports executable separately from loaded init"
            assert_contains "$out" 'cache: current' "matching dependency metadata is current"
            assert_contains "$out" 'not on PATH' "missing optional tools are explained"
            assert_contains "$out" DOCTOR_RC=0 "healthy metadata and initialized shell return success"
            ;;
        stale) assert_contains "$out" 'stale (dependency paths changed)' "detects Nix-style path invalidation" ;;
        command) assert_contains "$out" 'stale (init command changed)' "detects changed init command" ;;
        unloaded) assert_contains "$out" 'not attempted in this shell' "does not infer loaded status from an old cache" ;;
        missing) assert_contains "$out" 'cache: missing or unreadable' "reports missing cache" ;;
        metadata) assert_contains "$out" 'missing dependency metadata' "reports missing sidecar" ;;
        modified) assert_contains "$out" 'stale (dependency modified)' "detects mutable dependencies newer than cache" ;;
        failed) assert_contains "$out" 'init failed (status 75)' "reports failed initialization" ;;
        minimal) assert_contains "$out" 'intentionally skipped' "explains minimal-mode omissions" ;;
        insecure) assert_contains "$out" "$insecure" "reports insecure completion paths" ;;
        busy) assert_contains "$out" 'cache: busy or unreadable' "does not read a tool cache during a write transaction" ;;
        compbusy) assert_contains "$out" 'Completion cache busy or unreadable' "does not read completion metadata during a write transaction" ;;
    esac
done
[[ ! -e "$home/doctor-tool-called" ]] && t_pass "doctor never invokes integration binaries" || t_fail "doctor never invokes integration binaries"
typeset -a locks=("$cache_dir"/.cache-lock-*(N))
assert_eq "${#locks}" 0 "doctor does not create cache lock files"

# Exercise the real initialization recording and snapshot cache bytes before
# and after diagnosis in a fully initialized shell.
typeset sb="$(make_sandbox_home)"
out=$(run_sandbox_zsh "$sb" '
    _init_from_cache "$SHELL_CACHE_DIR/doctor-test.zsh" "print -r -- true"
    print -r -- "RECORDED=${_SHELL_INIT_STATUS[$SHELL_CACHE_DIR/doctor-test.zsh]}"
    _init_from_cache "$SHELL_CACHE_DIR/doctor-fail.zsh" false
    print -r -- "FAILED=${_SHELL_INIT_STATUS[$SHELL_CACHE_DIR/doctor-fail.zsh]}"
    before=$(command cksum "$SHELL_CACHE_DIR"/*(DN.))
    shell-doctor >/dev/null
    after=$(command cksum "$SHELL_CACHE_DIR"/*(DN.))
    [[ "$before" == "$after" ]] && print -r -- CACHE_UNCHANGED
' 2>/dev/null)
assert_contains "$out" RECORDED=0 "successful init records status for the current shell"
assert_contains "$out" FAILED=1 "failed init records status for the current shell"
assert_contains "$out" CACHE_UNCHANGED "doctor leaves cache file names and bytes unchanged"

t_finish
