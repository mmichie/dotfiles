#!/usr/bin/env zsh
source "${0:A:h}/lib.zsh"

typeset sb="$(make_sandbox_home)" out='' errf="$T_SCRATCH/startup.err"
# An environment-requested recovery shell must bypass even broken settings.
print -r -- 'print -ru2 -- EARLY_MUST_NOT_RUN; return 1' > "$sb/.zshrc.early.local"
print -r -- 'print -ru2 -- LATE_MUST_NOT_RUN' > "$sb/.zshrc.local"
print -r -- 'print -ru2 -- WORK_MUST_NOT_RUN' > "$sb/.zshrc-work-local"
out=$(run_sandbox_zsh "$sb" '
    print -r -- "PROMPT=$PROMPT"
    print -r -- "MODULES=${+functions[setup_environment]}${+functions[init_ssh]}${+functions[setup_integrations]}"
    [[ ! -d "$HOME/.cache/zsh" ]] && print -r -- NO_CACHE
    [[ ${path[1]} == "$HOME/bin" ]] && print -r -- PATH_OK
' ZSH_MINIMAL=1 PROFILE_STARTUP=1 PROFILE_STARTUP_RESET=1 2>"$errf")
assert_eq "$(<"$errf")" '' "minimal startup bypasses early and late local files"
assert_contains "$out" 'PROMPT=%n@%m:%~%# ' "minimal startup installs a plain prompt"
assert_contains "$out" 'MODULES=000' "minimal startup skips environment, SSH, and integration modules"
assert_contains "$out" NO_CACHE "minimal startup does not create completion or integration caches"
assert_contains "$out" PATH_OK "minimal startup retains zshenv PATH setup"
assert_not_contains "$out" 'num  calls' "minimal startup skips profiling"

print -r -- 'ZSH_MINIMAL=1' > "$sb/.zshrc.early.local"
out=$(run_sandbox_zsh "$sb" 'print -r -- "MINIMAL=$ZSH_MINIMAL MODULE=${+functions[setup_environment]}"' 2>"$errf")
assert_eq "$out" 'MINIMAL=1 MODULE=0' "early settings can select minimal startup"
assert_eq "$(<"$errf")" '' "minimal mode selected in settings skips late overrides"

# Normal startup: early settings precede modules, late overrides follow them,
# and both files are evaluated again on the documented reload path.
sb="$(make_sandbox_home)"
cat > "$sb/.zshrc.early.local" <<'EOF'
[[ ${EARLY_RUNS:-0} == 0 ]] && print -r -- "EARLY_MODULE=${+functions[setup_environment]}"
(( EARLY_RUNS += 1 ))
export STARTUP_SETTING=early
EOF
cat > "$sb/.zshrc.local" <<'EOF'
[[ $STARTUP_SETTING == early && ${+functions[setup_environment]} == 1 ]] && print -r -- ORDER_OK
STARTUP_SETTING=late
EOF
out=$(run_sandbox_zsh "$sb" '
    print -r -- "FIRST=$EARLY_RUNS/$STARTUP_SETTING"
    source ~/.zshrc
    print -r -- "RELOAD=$EARLY_RUNS/$STARTUP_SETTING"
' 2>/dev/null)
assert_contains "$out" ORDER_OK "normal startup runs settings before late overrides and initializes modules"
assert_contains "$out" 'EARLY_MODULE=0' "early settings run before environment initialization"
assert_contains "$out" 'FIRST=1/late' "late settings retain final precedence"
assert_contains "$out" 'RELOAD=2/late' "reload re-reads early and late settings"

t_finish
