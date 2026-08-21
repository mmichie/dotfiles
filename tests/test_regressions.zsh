#!/usr/bin/env zsh
# Regression tests pinning bugs fixed in the 2026-06 and 2026-07 zsh
# correctness reviews.
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

# Assignments, not bare declarations: zsh prints an already-set parameter
# when typeset names it with no value, and $out is set for every command in
# a nix build (the flake check runs the suite inside one).
typeset sb='' out=''
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
leftover=("$TMPDIR"/op-env.*(N))
print -r -- "OPENV_LEFTOVER=${#leftover}"

# A missing --account value used to make `shift 2` fail without consuming
# argv, leaving the parser in a tight infinite loop. Bound the regression
# probe so a broken implementation fails quickly instead of hanging CI.
op-env some-item --account >/dev/null 2>&1 &
probe_pid=$!
sleep 0.1
if kill -0 $probe_pid 2>/dev/null; then
    kill $probe_pid 2>/dev/null
    wait $probe_pid 2>/dev/null
    print -r -- "OPENV_MISSING_ACCOUNT=hung"
else
    wait $probe_pid
    print -r -- "OPENV_MISSING_ACCOUNT=rc:$?"
fi
EOF
typeset openvtmp="$T_SCRATCH/openvtmp"
mkdir -p "$openvtmp"
out=$(TMPDIR="$openvtmp" PATH="$opdir:$PATH" zsh --no-globalrcs -f "$inner" "$ZSH_CONF" 2>&1)
assert_contains "$out" "GOT=from_op" "op-env round-trips env through op stub (mktemp regression)"
assert_contains "$out" "OPENV_RC=0"  "op-env exits 0"
assert_contains "$out" "OPENV_LEFTOVER=0" "op-env removes its env tempfile (always-block cleanup)"
assert_contains "$out" "OPENV_MISSING_ACCOUNT=rc:2" "op-env rejects --account without a value instead of hanging"

# ── claude wrapper binary resolution (functions/claude) ──────────────
# Bug: `command -v claude` inside the wrapper resolves to the wrapper
# function itself — never empty, never a path — so the missing-binary
# guard was dead code. whence -p does a pure path search.
typeset claudebin="$T_SCRATCH/claudebin"
make_stub "$claudebin" claude 'echo "stub-claude:$@"; exit 7'
inner="$T_SCRATCH/claude_inner.zsh"
cat > "$inner" <<'EOF'
fpath=("$1/.zsh/functions" $fpath)
autoload -Uz claude
trap 'true' INT TERM EXIT
trap > "$2.before"
claude --probe
print -r -- "CLAUDE_RC=$?"
trap > "$2.after"
[[ "$(<"$2.before")" == "$(<"$2.after")" ]] && print -r -- "CLAUDE_TRAPS=preserved"
EOF
# The pinned PATH is the CHILD's search path (so only the stub dir can
# satisfy `claude`), but zsh itself must be spawned by absolute path: a
# temporary PATH assignment also governs the lookup of the command being
# run, and /usr/bin:/bin has no zsh inside a Linux nix sandbox or on
# current ubuntu runner images.
typeset claude_trap_probe="$T_SCRATCH/claude-traps"
out=$(TMUX= PATH="$claudebin:/usr/bin:/bin" "${commands[zsh]}" --no-globalrcs -f "$inner" "$ZSH_CONF" "$claude_trap_probe" 2>&1)
assert_contains "$out" "stub-claude:--probe" "claude wrapper dispatches to the PATH binary"
assert_contains "$out" "CLAUDE_RC=7"         "claude wrapper propagates the binary's exit code"
assert_contains "$out" "CLAUDE_TRAPS=preserved" "claude wrapper preserves caller signal and exit traps"
out=$(TMUX= PATH="/usr/bin:/bin" "${commands[zsh]}" --no-globalrcs -f "$inner" "$ZSH_CONF" "$claude_trap_probe" 2>&1)
assert_contains "$out" "claude command not found" "missing binary hits the guard (regression: command -v matched the function)"
assert_contains "$out" "CLAUDE_RC=1"              "missing claude returns 1"

# ── tmux title wrapper trap locality (lib/70-tmux-title.zsh) ──────────────
# Bug: the wrapper installed process-global traps and then cleared them,
# deleting any handlers the caller had installed before invoking it.
inner="$T_SCRATCH/tmux_title_traps_inner.zsh"
cat > "$inner" <<'EOF'
source "$1/.zsh/lib/70-tmux-title.zsh"
tmux() {
    [[ "$1" == display-message ]] && print -r -- '%1'
    return 0
}
trap 'true' INT TERM EXIT
trap > "$2.before"
TMUX=stub _tmux_title_wrap probe true
trap > "$2.after"
[[ "$(<"$2.before")" == "$(<"$2.after")" ]] && print -r -- "TMUX_WRAP_TRAPS=preserved"
EOF
typeset tmux_trap_probe="$T_SCRATCH/tmux-wrap-traps"
out=$(zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$tmux_trap_probe" 2>&1)
assert_contains "$out" "TMUX_WRAP_TRAPS=preserved" "tmux title wrapper preserves caller signal and exit traps"

# ── git_cleanup literal branch filtering (functions/git_cleanup) ────────
# Bug: default/current branch names were interpolated into grep -E. A valid
# name such as release+prod was treated as a regex and reached git branch -d.
typeset gitstubdir="$T_SCRATCH/gitstub"
make_stub "$gitstubdir" git 'case "$1:$2" in
    fetch:--prune) exit 0 ;;
    symbolic-ref:--short) printf "%s\n" "origin/release+prod" ;;
    show-ref:--verify) exit 0 ;;
    branch:--show-current) printf "%s\n" "feature" ;;
    branch:--merged) printf "%s\n" "release+prod" "old-feature" ;;
    branch:-d) printf "%s\n" "$3" >> "$GIT_DELETE_LOG" ;;
    *) exit 64 ;;
esac'
inner="$T_SCRATCH/git_cleanup_inner.zsh"
cat > "$inner" <<'EOF'
fpath=("$1/.zsh/functions" $fpath)
autoload -Uz git_cleanup
: > "$GIT_DELETE_LOG"
git_cleanup >/dev/null
deleted=("${(@f)$(<"$GIT_DELETE_LOG")}")
print -r -- "GIT_DELETED=${(j:,:)deleted}"
EOF
typeset git_delete_log="$T_SCRATCH/git-deleted.log"
out=$(PATH="$gitstubdir:$PATH" GIT_DELETE_LOG="$git_delete_log" zsh --no-globalrcs -f "$inner" "$ZSH_CONF" 2>&1)
assert_contains "$out" "GIT_DELETED=old-feature" "git_cleanup protects default branch names containing regex metacharacters"

# ── helper error statuses (functions/d, functions/sshtunnel) ────────────
inner="$T_SCRATCH/helper_status_inner.zsh"
cat > "$inner" <<'EOF'
fpath=("$1/.zsh/functions" $fpath)
autoload -Uz d sshtunnel
d --definitely-invalid >/dev/null 2>&1
print -r -- "D_BAD_RC=$?"
sshtunnel >/dev/null 2>&1
print -r -- "SSHTUNNEL_USAGE_RC=$?"
EOF
out=$(zsh --no-globalrcs -f "$inner" "$ZSH_CONF" 2>&1)
assert_contains "$out" "D_BAD_RC=1" "d propagates dirs errors instead of masking them"
assert_contains "$out" "SSHTUNNEL_USAGE_RC=1" "sshtunnel invalid usage returns failure"

# ── remember backslash fidelity (functions/remember) ─────────────────
# Bug: zsh echo expands \n and friends, so a remembered command containing
# backslash escapes was written as multiple mangled lines.
inner="$T_SCRATCH/remember_inner.zsh"
cat > "$inner" <<'EOF'
fpath=("$1/.zsh/functions" $fpath)
autoload -Uz remember
remember grep '\n' file >/dev/null
lines=(${(f)"$(<"$HOME/.important_commands")"})
print -r -- "REM_LINES=${#lines}"
[[ "${lines[1]}" == *"grep \n file" ]] && print -r -- "REM_LITERAL=yes"
EOF
typeset remhome="$T_SCRATCH/remhome"
mkdir -p "$remhome"
out=$(HOME="$remhome" zsh --no-globalrcs -f "$inner" "$ZSH_CONF" 2>&1)
assert_contains "$out" "REM_LINES=1"     "remember writes one line per save"
assert_contains "$out" "REM_LITERAL=yes" "remember preserves backslashes verbatim (regression: echo expanded them)"

# ── gam credential-helper cleanup (functions/gam) ────────────────────
# Bug: a failed credential pull returned early and skipped the
# unfunction, leaking _gam_pull into the shell.
inner="$T_SCRATCH/gam_inner.zsh"
cat > "$inner" <<'EOF'
fpath=("$1/.zsh/functions" $fpath)
autoload -Uz gam
gam info >/dev/null 2>&1
print -r -- "GAM_RC=$?"
(( $+functions[_gam_pull] )) && print -r -- "GAM_HELPER_LEAKED=yes"
print -r -- "GAM_END"
EOF
typeset gamhome="$T_SCRATCH/gamhome"
mkdir -p "$gamhome"
out=$(HOME="$gamhome" PATH="/usr/bin:/bin" "${commands[zsh]}" --no-globalrcs -f "$inner" "$ZSH_CONF" 2>&1)
assert_contains     "$out" "GAM_RC=1"          "gam fails closed without op"
assert_contains     "$out" "GAM_END"           "gam probe completes"
assert_not_contains "$out" "GAM_HELPER_LEAKED" "gam unfunctions _gam_pull on failure (regression)"

# ── keypress alias read flags (lib/30-aliases.zsh) ───────────────────
# Bug: `read -s -n1` is a bashism; zsh rejected it with "read: bad option".
# Option parsing happens before any input handling, so "bad option" is the
# regression signal. The probe injects -t0 -u0 into the alias body: never
# run the raw alias here — under a pty-allocating caller (lefthook) a bare
# `read -k` opens /dev/tty and blocks forever waiting for a keystroke.
sb="$(make_sandbox_home)"
out=$(run_sandbox_zsh "$sb" 'print -r -- "KP=${aliases[keypress]}"' 2>/dev/null)
assert_contains "$out" "read -sk1" "keypress alias uses zsh read -k"

typeset err=''
err=$(run_sandbox_zsh "$sb" 'eval "${aliases[keypress]/read /read -t0 -u0 }"' 2>&1 >/dev/null </dev/null)
assert_not_contains "$err" "bad option" "keypress read flags accepted by zsh (regression)"

# ── clipboard bodies vs the cat alias (lib/40-clipboard.zsh) ─────────
# Bug: 30-aliases.zsh aliases cat to bat, and zsh expands aliases while
# PARSING the later-sourced 40-clipboard.zsh — so the stored clipcopy body
# was `bat --style=plain --paging=never --wrap=never ... | pbcopy`, making
# clipboard bytes depend on bat's off-tty "behave like cat" fallback and
# forking bat per copy. Both modules are re-sourced in load order so the
# parse is pinned here regardless of how the module chain is renumbered.
#
# The backend is pinned too, so the assertion means the same thing on every
# platform: macOS takes the pbcopy branch, elsewhere an xsel stub plus
# DISPLAY takes the xsel branch. Both pipe through cat; the tmux and
# no-backend branches read no file at all and would go vacuous.
typeset xseldir="$T_SCRATCH/xselbin"
make_stub "$xseldir" xsel
sb="$(make_sandbox_home)"
out=$(run_sandbox_zsh "$sb" '
source "$SHELL_LIB_DIR/30-aliases.zsh"
source "$SHELL_LIB_DIR/40-clipboard.zsh"
path=("$XSELDIR" $path)
export DISPLAY=":0"
detect-clipboard
print -r -- "CAT_ALIAS=${+aliases[cat]}"
print -r -- "COPY=${functions[clipcopy]//[[:space:]]/ }"
print -r -- "PASTE=${functions[clippaste]//[[:space:]]/ }"
' XSELDIR="$xseldir" 2>/dev/null)
assert_contains "$out" 'COPY= command cat "${1:-/dev/stdin}"' \
    "clipcopy reads its input through an alias-immune command cat"
if [[ "$out" == *"CAT_ALIAS=1"* ]]; then
    assert_not_contains "$out" "bat" \
        "no clipboard body carries an expanded cat alias (regression)"
else
    t_skip "no clipboard body carries an expanded cat alias" \
        "bat not in PATH, so 30-aliases.zsh defines no cat alias"
fi

# ── sudo interactive detection: flag-value false positive (lib/80-ssh.zsh)
# Bug: the sudo() wrapper's `for arg in "$@"` loop checked every word
# against -i|-s|su without skipping the value of -u.  `sudo -u su make`
# falsely matched "su" (a username) as the interactive `su` command,
# pinning a ⚠️ ROOT title on a non-interactive command.  Long forms
# --login/--shell were also missed (false negative).
#
# The test exercises the REAL sudo() from 80-ssh.zsh (via run_sandbox_zsh,
# which sources the full .zshrc with agent stubs).  _sudo_bin is stubbed
# to echo and tmux is stubbed to capture the @is_root marker; the
# interactive path sets it, the direct path does not.
sb="$(make_sandbox_home)"
out=$(run_sandbox_zsh "$sb" '
typeset -g _sudo_bin=echo
_tmux_root_set=0
tmux() {
    [[ "$1" == display-message ]] && { print -r -- "%1"; return 0 }
    [[ "$1" == set-option ]] && {
        for _a in "$@"; do
            [[ "$_a" == "@is_root" ]] && _tmux_root_set=1
        done
    }
    return 0
}
sudo -u su make
print -r -- "ROOT_SU=$_tmux_root_set"
_tmux_root_set=0
sudo su
print -r -- "ROOT_BARE=$_tmux_root_set"
_tmux_root_set=0
sudo --login
print -r -- "ROOT_LOGIN=$_tmux_root_set"
_tmux_root_set=0
sudo --shell
print -r -- "ROOT_SHELL=$_tmux_root_set"
_tmux_root_set=0
sudo echo su
print -r -- "ROOT_ECHO_SU=$_tmux_root_set"
_tmux_root_set=0
sudo -g su make
print -r -- "ROOT_G_SU=$_tmux_root_set"
' TMUX=1 2>/dev/null)
assert_contains     "$out" "ROOT_SU=0" \
    "sudo -u su make does not mark root (su is a username, not interactive)"
assert_contains     "$out" "ROOT_BARE=1" \
    "sudo su marks root (interactive)"
assert_contains     "$out" "ROOT_LOGIN=1" \
    "sudo --login marks root (long form of -i, interactive)"
assert_contains     "$out" "ROOT_SHELL=1" \
    "sudo --shell marks root (long form of -s, interactive)"
assert_contains     "$out" "ROOT_ECHO_SU=0" \
    "sudo echo su does not mark root (su is a command arg, not interactive)"
assert_contains     "$out" "ROOT_G_SU=0" \
    "sudo -g su make does not mark root (su is a group value, not interactive)"

t_finish
