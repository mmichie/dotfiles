#!/usr/bin/env zsh
# Regression tests pinning bugs fixed in the 2026-06 zsh correctness review.
# (The _parse_env_file and arrow-binding regressions live in their own files.)

source "${0:A:h}/lib.zsh"

# ── JAVA_HOME lazy resolution (lib/10-environment.zsh) ───────────────
# Bug: _java_home_lazy used `command -v javac`, which returned the lazy
# wrapper *function* name; :A resolved it against $PWD, so JAVA_HOME became
# the grandparent of the current directory.
#
# A stub jdk is prepended to path *inside* the shell: .zshenv's setup_path
# puts its fixed directories ahead of the inherited PATH, so an env-level
# prepend gets demoted below any real jdk — or below macOS's /usr/bin/javac
# locator stub, which spins forever when no JDK is installed. The trigger is
# also gated on the lookup actually hitting the stub so a lookup regression
# fails fast instead of hanging the suite.
typeset fakejdk="$T_SCRATCH/fakejdk"
make_stub "$fakejdk/bin" javac "exit 0"

typeset sb out
sb="$(make_sandbox_home)"
out=$(run_sandbox_zsh "$sb" '
    path=("$FAKEJDK/bin" $path)
    cd "$HOME"
    print -r -- "M_JAVAC=$(whence -p javac)"
    if [[ "$(whence -p javac)" == "$FAKEJDK/bin/javac" ]]; then
        javac >/dev/null 2>&1
        print -r -- "JH=$JAVA_HOME"
        [[ -n "$JAVA_HOME" && -x "$JAVA_HOME/bin/javac" ]] && print -r -- "JH_VALID=yes"
        whence -w java | grep -q function && print -r -- "WRAPPER_LEAKED=yes"
    fi
' FAKEJDK="$fakejdk" 2>/dev/null)
assert_contains     "$out" "M_JAVAC=$fakejdk/bin/javac" "stub jdk wins the javac lookup"
assert_contains     "$out" "JH_VALID=yes"      "JAVA_HOME points at a real JDK home (regression)"
assert_not_contains "$out" "WRAPPER_LEAKED"    "lazy wrappers unfunction themselves after first use"

# ── op-env mktemp portability (functions/op-env) ─────────────────────
# Bug: `mktemp -t op-env` fails under GNU mktemp ("too few X's in template"),
# which is what nix coreutils puts in PATH. Run op-env end-to-end against a
# stub `op` so the real mktemp call is exercised without touching 1Password.
typeset opdir="$T_SCRATCH/opbin"
make_stub "$opdir" op 'case "$1" in
    item)
        printf "FOO=from_op\n"
        ;;
    run)
        shift
        envfile=
        while [ $# -gt 0 ]; do
            case "$1" in
                --env-file=*) envfile="${1#--env-file=}" ;;
                --) shift; break ;;
            esac
            shift
        done
        set -a; . "$envfile"; set +a
        exec "$@"
        ;;
    *)
        exit 64
        ;;
esac'

typeset inner="$T_SCRATCH/openv_inner.zsh"
cat > "$inner" <<'EOF'
fpath=("$1/.zsh/functions" $fpath)
autoload -Uz op-env
op-env some-item -- /bin/sh -c 'printf "GOT=%s\n" "$FOO"'
print -r -- "OPENV_RC=$?"
EOF
out=$(PATH="$opdir:$PATH" zsh --no-globalrcs -f "$inner" "$ZSH_CONF" 2>&1)
assert_contains "$out" "GOT=from_op" "op-env round-trips env through op stub (mktemp regression)"
assert_contains "$out" "OPENV_RC=0"  "op-env exits 0"

# ── keypress alias read flags (lib/30-aliases.zsh) ───────────────────
# Bug: `read -s -n1` is a bashism; zsh rejected it with "read: bad option".
# Option parsing happens before any input handling, so "bad option" is the
# regression signal. The probe injects -t0 -u0 into the alias body: never
# run the raw alias here — under a pty-allocating caller (lefthook) a bare
# `read -k` opens /dev/tty and blocks forever waiting for a keystroke.
sb="$(make_sandbox_home)"
out=$(run_sandbox_zsh "$sb" 'print -r -- "KP=${aliases[keypress]}"' 2>/dev/null)
assert_contains "$out" "read -sk1" "keypress alias uses zsh read -k"

typeset err
err=$(run_sandbox_zsh "$sb" 'eval "${aliases[keypress]/read /read -t0 -u0 }"' 2>&1 >/dev/null </dev/null)
assert_not_contains "$err" "bad option" "keypress read flags accepted by zsh (regression)"

t_finish
