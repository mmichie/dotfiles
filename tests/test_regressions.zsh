#!/usr/bin/env zsh
# Regression tests pinning bugs fixed in the 2026-06, 2026-07 and 2026-09 zsh
# correctness reviews, the 2026-10 forwarded-agent fix and the 2026-11
# interactive-behaviour fixes (completers, directory jumps, spelling
# correction, less history, history N, exported tuning parameters, nsa).
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

# ── tmux title pop clears the Claude Code state mark ──────────────────
# The claude wrapper pops on exit, including after a crash or kill that
# skipped the session's SessionEnd hook; a leftover mark flags a shell pane.
inner="$T_SCRATCH/tmux_title_pop_inner.zsh"
cat > "$inner" <<'EOF'
source "$1/.zsh/lib/70-tmux-title.zsh"
typeset -g pop_log="$2"
tmux() { print -r -- "$*" >> "$pop_log"; return 0 }
_tmux_title_pop %1 @1
EOF
typeset pop_probe="$T_SCRATCH/tmux-pop.log"
zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$pop_probe" >/dev/null 2>&1
assert_contains "$(<"$pop_probe")" "set-option -t %1 -p @claude_state" \
    "title pop clears the Claude Code state mark"

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
_tmux_root_set=0
sudo -iu root
print -r -- "ROOT_IU=$_tmux_root_set"
_tmux_root_set=0
sudo -Eu root -i
print -r -- "ROOT_EU_I=$_tmux_root_set"
_tmux_root_set=0
sudo -Es
print -r -- "ROOT_ES=$_tmux_root_set"
_tmux_root_set=0
sudo -Eu root make
print -r -- "ROOT_EU_MAKE=$_tmux_root_set"
_tmux_root_set=0
sudo --user su make
print -r -- "ROOT_USER_SU=$_tmux_root_set"
_tmux_root_set=0
sudo --non-interactive su
print -r -- "ROOT_NONVALUED_SU=$_tmux_root_set"
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
# Joined clusters: booleans may precede -i/-s or one valued option whose value
# is the rest of the cluster or the next argument. Bug: -iu root, -Eu root -i
# and -Es were all read as opaque flags and never marked root.
assert_contains     "$out" "ROOT_IU=1" \
    "sudo -iu root marks root (interactive flag inside a cluster)"
assert_contains     "$out" "ROOT_EU_I=1" \
    "sudo -Eu root -i marks root (valued option at cluster end consumes root)"
assert_contains     "$out" "ROOT_ES=1" \
    "sudo -Es marks root (-s inside a cluster)"
assert_contains     "$out" "ROOT_EU_MAKE=0" \
    "sudo -Eu root make does not mark root"
# Long options: a valued one (--user) consumes the next word, a boolean one
# (--non-interactive) does not.
assert_contains     "$out" "ROOT_USER_SU=0" \
    "sudo --user su make does not mark root (su is the --user value)"
assert_contains     "$out" "ROOT_NONVALUED_SU=1" \
    "sudo --non-interactive su marks root (a boolean long option takes no value)"

# ── zoxide init generation-time env (lib/50-integrations.zsh) ────────
# Bug: setup_zoxide exported _ZO_ECHO and _ZO_RESOLVE_SYMLINKS AFTER
# running `zoxide init zsh`, but zoxide reads both while GENERATING its
# script and bakes them in (pwd -P vs -L, the matched-dir echo after cd);
# the emitted functions never consult them. A shell that did not already
# inherit the exports cached the silent pwd -L variant, and the .dep
# fingerprint (command string + resolved binary) could not tell the two
# apart, so it stuck until zoxide's store path moved. The sandbox boots
# under env -i, which is exactly the no-inheritance case; the assertions
# read the functions the shell actually loaded, not the file on disk.
if have zoxide; then
    sb="$(make_sandbox_home)"
    out=$(run_sandbox_zsh "$sb" '
        print -r -- "ZO_PWD=${functions[__zoxide_pwd]//[[:space:]]/ }"
        print -r -- "ZO_CD=${functions[__zoxide_cd]//[[:space:]]/ }"
    ' 2>/dev/null)
    assert_contains "$out" '\builtin pwd -P' \
        "zoxide init sees _ZO_RESOLVE_SYMLINKS at generation (regression: exported after init)"
    assert_contains "$out" 'cd -- "$@" && __zoxide_pwd' \
        "zoxide init sees _ZO_ECHO at generation: cd echoes the matched dir (regression)"
else
    t_skip "zoxide init generation-time env" "zoxide not in PATH"
fi

# ── Suffix alias opener per platform (lib/30-aliases.zsh) ───────────
# Bug: the image and HTML suffix aliases were hard-coded to `open`, which
# exists only on macOS: Debian-family Linux ships that name as openvt
# (console switching) and NixOS has none, so `foo.png` at a Linux prompt
# ran the wrong program or nothing. The opener is chosen per platform
# (open on macOS, xdg-open elsewhere) and the aliases are skipped when no
# opener is installed. Platform is pinned through SYSTEM_OS_TYPE, which
# is_osx reads, so every branch runs on every host; PATH is pinned to a
# stub dir so xdg-open's presence is controlled, not inherited.
typeset xdgdir="$T_SCRATCH/xdgbin" emptydir="$T_SCRATCH/emptybin"
make_stub "$xdgdir" xdg-open
mkdir -p "$emptydir"
sb="$(make_sandbox_home)"
out=$(run_sandbox_zsh "$sb" '
typeset -a saved_path=("$path[@]")
unalias -s gif jpg jpeg png html htm 2>/dev/null
SYSTEM_OS_TYPE=LINUX
path=("$EMPTYDIR"); rehash
source "$SHELL_LIB_DIR/30-aliases.zsh"
print -r -- "OPENER_LINUX_NONE=${+saliases[png]}${+saliases[html]}"
unalias -s gif jpg jpeg png html htm 2>/dev/null
path=("$XDGDIR" "$EMPTYDIR"); rehash
source "$SHELL_LIB_DIR/30-aliases.zsh"
print -r -- "OPENER_LINUX_XDG=${saliases[png]}/${saliases[html]}"
unalias -s gif jpg jpeg png html htm 2>/dev/null
SYSTEM_OS_TYPE=OSX
source "$SHELL_LIB_DIR/30-aliases.zsh"
print -r -- "OPENER_OSX=${saliases[png]}/${saliases[html]}"
[[ ${saliases[md]} == $EDITOR ]] && print -r -- "OPENER_MD_EDITOR=yes"
path=("$saved_path[@]")
' XDGDIR="$xdgdir" EMPTYDIR="$emptydir" 2>/dev/null)
assert_contains "$out" "OPENER_LINUX_NONE=00" \
    "Linux without xdg-open defines no image/HTML suffix aliases (regression: bound to macOS open)"
assert_contains "$out" "OPENER_LINUX_XDG=xdg-open/xdg-open" \
    "Linux with xdg-open binds image/HTML suffixes to it"
assert_contains "$out" "OPENER_OSX=open/open" "macOS binds image/HTML suffixes to open"
assert_contains "$out" "OPENER_MD_EDITOR=yes" "text suffixes open in \$EDITOR on every platform"

# ── Forwarded-agent link follows any login path (lib/80-ssh.zsh) ─────
# Bug: ~/.ssh/ssh_auth_sock, the one SSH_AUTH_SOCK every pane exports, was
# repointed only by ~/.ssh/rc, which sshd runs and Tailscale SSH does not
# (it spawns login(1) directly). A Tailscale login never published its
# forwarded socket, and once the sshd login that had last pointed the link
# ended, every pane sat on a dead path while another login's live socket
# went unused. The shell now owns the link: a login adopts the forwarded
# socket it arrived with, a dead link is repaired from any other live
# forwarded socket, and with none it is parked on the local agent, so a
# pane keeps one path and follows the next login. Liveness is a connect
# (zsocket), not -S: a socket file outlives its listener.
#
# Two listeners stand in for two logins' forwarded sockets. zsocket -l
# listens with a backlog of one and never accepts, so a second probe of
# the same socket would block in connect(2): a background job drains each
# listener, and ending a login means killing its drain job as well as
# closing the fd. The scan patterns are confined to the scratch dir so a
# real forwarded login on the test machine cannot be adopted, and the stub
# dir is prepended inside the shell (.zshenv demotes an env-level prepend
# below the real ssh-agent).
_t_drain() {
    local fd
    while zsocket -a "$1" 2>/dev/null; do
        fd=$REPLY
        exec {fd}>&-
    done
}
if [[ -n "$T_AGENT_SOCK" ]]; then
    typeset fwd="$T_SCRATCH/fwd" login_sock='' other_sock=''
    typeset -i login_fd=0 other_fd=0 login_drain=0 other_drain=0
    mkdir -p "$fwd"
    login_sock="$fwd/s.a.sshd.login"
    other_sock="$fwd/s.b.sshd.other"
    zsocket -l "$login_sock"; login_fd=$REPLY
    _t_drain "$login_fd" & login_drain=$!
    zsocket -l "$other_sock"; other_fd=$REPLY
    # Forked with login_fd open: without closing that copy, this job would
    # keep the login's listener up after the login ends below.
    { exec {login_fd}>&-; _t_drain "$other_fd"; } & other_drain=$!
    sb="$(make_sandbox_home)"
    # Without the 1Password sockets the real agent logic runs.
    rm -f "$sb/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock" "$sb/.1password/agent.sock"
    out=$(run_sandbox_zsh "$sb" '
        link="$HOME/.ssh/ssh_auth_sock"
        print -r -- "BOOT=$SSH_AUTH_SOCK"
        AGENT_FORWARDED_GLOBS=("$FWD/s.*.sshd.*")
        SSH_AUTH_SOCK="$LOGIN_SOCK"; handle_ssh_agent
        print -r -- "ADOPT=$SSH_AUTH_SOCK:$(readlink "$link")"
        handle_ssh_agent
        print -r -- "PANE=$SSH_AUTH_SOCK:$(readlink "$link")"
        SSH_AUTH_SOCK="$AGENT_SOCKET"; handle_ssh_agent
        print -r -- "INHERITED=$SSH_AUTH_SOCK:$(readlink "$link")"
    ' FWD="$fwd" LOGIN_SOCK="$login_sock" 2>/dev/null)
    assert_contains "$out" "BOOT=$T_AGENT_SOCK" \
        "an externally provided live agent is kept as is (systemd user socket)"
    assert_contains "$out" "ADOPT=$sb/.ssh/ssh_auth_sock:$login_sock" \
        "a login publishes its forwarded socket through the link without ~/.ssh/rc (regression: Tailscale SSH)"
    assert_contains "$out" "PANE=$sb/.ssh/ssh_auth_sock:$login_sock" \
        "a pane on a live link is left alone"
    assert_contains "$out" "INHERITED=$sb/.ssh/ssh_auth_sock:$login_sock" \
        "a pane that inherited the local agent path moves to the live link (regression)"

    # The login behind the link ends; its socket file stays behind, dead.
    # The other login is still up, so the boot finds a live link and the
    # sandbox never touches the harness dummy again (it is never drained).
    kill "$login_drain" 2>/dev/null; wait "$login_drain" 2>/dev/null
    exec {login_fd}>&-
    # Make it the newest file: the scan goes newest first, so it reaches the
    # dead socket before the live one and has to reject it on the connect.
    # Creation order alone would put the live socket first or, where a coarse
    # clock gives both one mtime, leave the order to the directory.
    touch "$login_sock"
    ln -snf "$other_sock" "$sb/.ssh/ssh_auth_sock"
    out=$(run_sandbox_zsh "$sb" '
        path=("$STUBS" $path); rehash
        link="$HOME/.ssh/ssh_auth_sock"
        AGENT_FORWARDED_GLOBS=("$FWD/s.*.sshd.*")
        ln -snf "$HOME/gone" "$link"
        SSH_AUTH_SOCK="$link"; handle_ssh_agent
        print -r -- "REPAIR=$SSH_AUTH_SOCK:$(readlink "$link")"
        ln -snf "$HOME/gone" "$link"
        AGENT_FORWARDED_GLOBS=("$HOME/none/*")
        SSH_AUTH_SOCK="$link"; handle_ssh_agent >/dev/null
        print -r -- "LOCAL=$SSH_AUTH_SOCK:$(readlink "$link"):$(whence -p ssh-agent)"
    ' FWD="$fwd" STUBS="$T_AGENT_STUBS" 2>/dev/null)
    assert_contains "$out" "REPAIR=$sb/.ssh/ssh_auth_sock:$other_sock" \
        "a dead link is repaired from another login still alive, skipping the dead socket file (regression)"
    assert_contains "$out" "LOCAL=$sb/.ssh/ssh_auth_sock:$sb/.ssh/.ssh-agent-socket:$T_AGENT_STUBS/ssh-agent" \
        "with nothing forwarded the link parks on the (stubbed) local agent, still the one path panes export"
    kill "$other_drain" 2>/dev/null; wait "$other_drain" 2>/dev/null
    exec {other_fd}>&-
else
    t_skip "forwarded-agent link follows any login path" "no unix socket listener (zsocket)"
fi

# ── kill/finger completers are real functions (lib/25-completion.zsh) ─
# Bug: setup_completions ran `compdef _signal kill` and `compdef _user finger
# pinky`, and zsh has neither function. The block was carried over from
# bash's `complete -A signal kill` / `complete -A user finger pinky` by
# prefixing an underscore; zsh's names are _signals and _users. compdef
# registers any name unchecked, so the override replaced the stock _kill
# (signals, PIDs, jobs) and _finger with a dangling entry: TAB after `kill`
# printed "(eval):1: command not found: _signal" and completed nothing.
#
# The dangling check is the general invariant, read from the shell the whole
# module chain built: every completer in $_comps is a function, defined or
# marked for autoload. compinit registers only files it found on fpath, so a
# dangling entry can only come from an explicit compdef in this config or in
# a tool init it sources.
sb="$(make_sandbox_home)"
out=$(run_sandbox_zsh "$sb" '
typeset -a comp_dangling=()
typeset comp_cmd="" comp_fn=""
for comp_cmd comp_fn in "${(@kv)_comps}"; do
    (( $+functions[${comp_fn%% *}] )) || comp_dangling+=("$comp_cmd=$comp_fn")
done
print -r -- "COMP_REGISTERED=$(( ${#_comps} > 0 ))"
print -r -- "COMP_KILL=${_comps[kill]}"
print -r -- "COMP_FINGER=${_comps[finger]}"
print -r -- "COMP_DANGLING=[${(j:,:)${(@o)comp_dangling}}]"
' 2>/dev/null)
assert_contains "$out" "COMP_REGISTERED=1" \
    "completion table is populated (keeps the dangling-completer check from passing vacuously)"
assert_eq "${${out##*COMP_DANGLING=}%%$'\n'*}" "[]" \
    "every registered completer is a function (regression: kill -> _signal, finger/pinky -> _user)"
assert_contains "$out" "COMP_KILL=_kill"     "kill keeps stock _kill completer (signals, PIDs, jobs)"
assert_contains "$out" "COMP_FINGER=_finger" "finger keeps stock _finger completer (users, hosts)"

# End to end on a real command line: complete `kill -HU` the way TAB does.
# zle-line-init drives the widget without keystrokes, as test_history_widget
# does, but from the shell's own prompt and not from vared: completion inside
# vared is value context and never consults $_comps[kill]. ~/.zshrc.local is
# the last file .zshrc sources, so the probe runs in the finished shell. HUP
# is the only signal that starts with HU, so a working completer inserts it;
# the dangling one left the buffer alone and printed the error. The always
# block exits the shell even if the probe body fails, so a regression shows
# up as a failed assertion and not as a hung boot. The boot starts in the
# sandbox HOME, where a direnv hook has no .envrc to report on.
cat > "$sb/.zshrc.local" <<'EOF'
_t_kill_tab_probe() {
    {
        BUFFER='kill -HU'
        CURSOR=${#BUFFER}
        zle expand-or-complete
        print -r -- "KILL_TAB_BUFFER=<$BUFFER>"
    } always {
        BUFFER=' exit'
        zle .accept-line
    }
}
zle -N zle-line-init _t_kill_tab_probe
EOF
_sandbox_env_args "$sb"
if out=$(cd "$sb" && run_under_pty env -i "${reply[@]}" zsh --no-globalrcs -i); then
    assert_contains "$out" "KILL_TAB_BUFFER=<kill -HUP" \
        "TAB after \`kill -HU\` completes the signal name on a real command line"
    assert_not_contains "$out" "command not found: _signal" \
        "TAB after \`kill\` runs a completer that exists (regression)"
else
    t_skip "kill TAB completion on a real command line" "PTY unavailable"
fi

# ── Numeric directory jumps follow d's numbering (lib/30-aliases.zsh) ─
# Bug: the 1..5 functions ran `cd -N`. Without PUSHD_MINUS, -N counts from
# the BOTTOM of the directory stack, so the number typed was not the number
# `d` (dirs -v) prints next to the directory: with four directories visited,
# `1` landed on the entry d numbers 3. The idiom comes from oh-my-zsh, which
# pairs it with `setopt pushdminus`; this config never set that. The jumps run
# in command substitutions so both start from the same stack.
typeset stackroot="$T_SCRATCH/dirstack"
mkdir -p "$stackroot"/{one,two,three,four}
sb="$(make_sandbox_home)"
out=$(run_sandbox_zsh "$sb" '
cd "$STACK/one"; cd "$STACK/two"; cd "$STACK/three"; cd "$STACK/four"
typeset -a d_listing=("${(@f)$(d)}")
print -r -- "D_ENTRY1=${d_listing[2]:t} D_ENTRY3=${d_listing[4]:t}"
print -r -- "JUMP1=$( { 1 } >/dev/null; print -rn -- "${PWD:t}" )"
print -r -- "JUMP3=$( { 3 } >/dev/null; print -rn -- "${PWD:t}" )"
' STACK="$stackroot" 2>/dev/null)
assert_contains "$out" "D_ENTRY1=three D_ENTRY3=one" "d numbers the stack from the most recent directory"
assert_contains "$out" "JUMP1=three" \
    "1 jumps to the entry d numbers 1 (regression: cd -1 counted from the bottom of the stack)"
assert_contains "$out" "JUMP3=one"   "3 jumps to the entry d numbers 3"

# ── Spelling correction never offers a dot-name (.zshrc) ──────────────
# Bug: the setting that should stop "correct 'claude' to '.claude'?" was
# CORRECT_IGNORE='(.*|claude)'. That prompt offers a FILE name (the .claude
# directory), and zsh filters file candidates with CORRECT_IGNORE_FILE only;
# CORRECT_IGNORE covers command names, so the dot pattern never applied and
# the `claude` alternative did one thing: stop typos such as `claud` from
# being corrected to claude. The original line, from 2025-05, did name
# CORRECT_IGNORE_FILE, with a pattern that could not match.
#
# spell-word runs the same correction code as the prompt and rewrites the
# word in place with no [nyae] question, so zle-line-init can drive it. The
# dot entry has a made-up name: no host command can be near it.
typeset corrdir="$T_SCRATCH/correct"
mkdir -p "$corrdir/.zzdotname"
sb="$(make_sandbox_home)"
cat > "$sb/.zshrc.local" <<'EOF'
_t_spell_probe() {
    {
        BUFFER='zzdotname'
        CURSOR=${#BUFFER}
        zle spell-word
        print -r -- "SPELL_DOTFILE=<$BUFFER>"
        BUFFER='claud'
        CURSOR=${#BUFFER}
        zle spell-word
        print -r -- "SPELL_TYPO=<$BUFFER>"
    } always {
        BUFFER=' exit'
        zle .accept-line
    }
}
zle -N zle-line-init _t_spell_probe
EOF
_sandbox_env_args "$sb"
if out=$(cd "$corrdir" && run_under_pty env -i "${reply[@]}" zsh --no-globalrcs -i); then
    assert_contains "$out" "SPELL_DOTFILE=<zzdotname>" \
        "a command zsh cannot find is not corrected to a dot-entry of the same name (regression)"
    assert_contains "$out" "SPELL_TYPO=<claude>" \
        "a typo of claude is corrected to claude (regression: CORRECT_IGNORE named it)"
else
    t_skip "spelling correction ignore patterns" "PTY unavailable"
fi

# ── less history has a directory to land in (lib/10-environment.zsh) ──
# Bug: LESSHISTFILE pointed at $XDG_CACHE_HOME/less/history and nothing
# created $XDG_CACHE_HOME/less. less does not create missing parents; it
# skips the write without a word, so search history was never saved.
sb="$(make_sandbox_home)"
out=$(run_sandbox_zsh "$sb" '
print -r -- "LESSHIST=$LESSHISTFILE"
[[ -d "${LESSHISTFILE:h}" ]] && print -r -- "LESSHIST_DIR=yes"
' 2>/dev/null)
assert_contains "$out" "LESSHIST=$sb/.cache/less/history" "LESSHISTFILE stays under the cache dir"
assert_contains "$out" "LESSHIST_DIR=yes" \
    "the directory LESSHISTFILE points into exists after startup (regression: less saved no history)"

# ── history N lists the last N, as bash does (functions/history) ──────
# Bug: `alias history="history 1"` ("behave more like bash") made bare
# `history` list everything, but the alias also prefixed every argument:
# `history 2` became `history 1 2`, the two OLDEST events, and zsh's own
# `history -3` became `history 1 -3`. history is a function now. zsh stops
# applying HIST_NO_STORE to `history ...` lines once a function of that name
# exists, so lib/20-history.zsh restates the rule in a zshaddhistory hook;
# the stored-events check pins it.
#
# Event numbers and "the last N" only mean something on a real command line,
# so zle-line-init feeds a queue of commands to the shell's own prompt and
# each listing is redirected to a file in the sandbox HOME.
hist_cmds() {
    # Command column of a history listing, joined with |: "    3  echo three".
    local line
    local -a cmds
    for line in ${(f)"$(<$1)"}; do
        cmds+=("${line#*[0-9]  }")
    done
    print -r -- "${(j:|:)cmds}"
}
sb="$(make_sandbox_home)"
cat > "$sb/.zshrc.local" <<'EOF'
typeset -ga _t_hist_queue=(
    'echo one' 'echo two' 'echo three' 'echo four'
    'history 2 > ~/h-n.out'
    'history > ~/h-bare.out'
    'history -3 > ~/h-dash.out'
    'history 0 > ~/h-zero.out'
    'fc -l 1 > ~/h-stored.out'
    'recent 2 > ~/h-recent.out'
)
_t_hist_drive() {
    if (( ${#_t_hist_queue} )); then
        BUFFER=${_t_hist_queue[1]}
        shift _t_hist_queue
    else
        BUFFER=' exit'
    fi
    zle .accept-line
}
zle -N zle-line-init _t_hist_drive
EOF
_sandbox_env_args "$sb"
if out=$(cd "$sb" && run_under_pty env -i "${reply[@]}" zsh --no-globalrcs -i); then
    assert_eq "$(hist_cmds "$sb/h-n.out")" "echo three|echo four" \
        "history N lists the last N events (regression: the alias made it events 1 to N)"
    assert_eq "$(hist_cmds "$sb/h-bare.out")" "echo one|echo two|echo three|echo four" \
        "bare history lists every event"
    assert_eq "$(hist_cmds "$sb/h-dash.out")" "echo two|echo three|echo four" \
        "zsh's own history -N still lists the last N (regression: the alias prefixed it too)"
    if [[ -e "$sb/h-zero.out" && ! -s "$sb/h-zero.out" ]]; then
        t_pass "history 0 lists nothing"
    else
        t_fail "history 0 lists nothing" "$(<"$sb/h-zero.out")"
    fi
    assert_eq "$(hist_cmds "$sb/h-stored.out")" "echo one|echo two|echo three|echo four" \
        "history invocations are not stored: HIST_NO_STORE holds for the function too"
    assert_eq "$(hist_cmds "$sb/h-recent.out")" "echo three|echo four" \
        "recent N still lists the last N through the function"
else
    t_skip "history listing on a real command line" "PTY unavailable"
fi

# ── zsh tuning parameters stay out of the environment (lib/10-environment.zsh)
# Bug: WORDCHARS, TIMEFMT, REPORTTIME and KEYTIMEOUT were exported. They tune
# the interactive shell, but every zsh it started inherited them: with
# REPORTTIME=10 in its environment a non-interactive zsh prints a timing
# block after any command that used more than 10 CPU seconds, into whatever
# was reading its stderr. Same class as the HISTFILE export. The boot is
# handed exported copies to pin that an inherited flag is stripped as well.
sb="$(make_sandbox_home)"
out=$(run_sandbox_zsh "$sb" '
typeset -a tune_env=(${(M)${(f)"$(command env)"}:#(WORDCHARS|TIMEFMT|REPORTTIME|KEYTIMEOUT)=*})
print -r -- "TUNE_SET=$REPORTTIME/$KEYTIMEOUT/${+WORDCHARS}/${+TIMEFMT}"
print -r -- "TUNE_ENV=[${(j:,:)${(@o)tune_env%%=*}}]"
' REPORTTIME=99 KEYTIMEOUT=77 2>/dev/null)
assert_contains "$out" "TUNE_SET=10/1/1/1" "the interactive shell keeps its own tuning"
assert_eq "${${out##*TUNE_ENV=}%%$'\n'*}" "[]" \
    "zsh tuning parameters are not exported, inherited flags included (regression: REPORTTIME reached every child zsh)"

# ── nsa stops at the UNIX-domain section on macOS too (lib/30-aliases.zsh)
# Bug: nsa cuts netstat -an at the UNIX-domain header, matched as the
# literal "Active UNIX domain sockets". That is Linux's wording; macOS
# prints "Active LOCAL (UNIX) domain sockets", so there the range never
# closed and nsa was plain netstat -an. A stub netstat replays both layouts.
typeset nsdir="$T_SCRATCH/netstatbin"
mkdir -p "$nsdir"
cat > "$nsdir/netstat" <<'EOF'
#!/bin/sh
if [ "$NETSTAT_STYLE" = mac ]; then
    echo "Active Internet connections (including servers)"
    echo "tcp4       0      0  127.0.0.1.631          *.*                    LISTEN"
    echo "Active Multipath Internet connections"
    echo "Active LOCAL (UNIX) domain sockets"
    echo "UNIXROW /var/run/mDNSResponder"
else
    echo "Active Internet connections (servers and established)"
    echo "tcp        0      0 0.0.0.0:22              0.0.0.0:*               LISTEN"
    echo "Active UNIX domain sockets (servers and established)"
    echo "UNIXROW /run/systemd/notify"
fi
EOF
chmod +x "$nsdir/netstat"
sb="$(make_sandbox_home)"
out=$(run_sandbox_zsh "$sb" '
path=("$NSDIR" $path); rehash
export NETSTAT_STYLE=mac
print -r -- "NSA_MAC=<${(j:|:)${(@f)$(eval "${aliases[nsa]}")}}>"
export NETSTAT_STYLE=linux
print -r -- "NSA_LINUX=<${(j:|:)${(@f)$(eval "${aliases[nsa]}")}}>"
' NSDIR="$nsdir" 2>/dev/null)
typeset nsa_mac="${${out##*NSA_MAC=}%%$'\n'*}" nsa_linux="${${out##*NSA_LINUX=}%%$'\n'*}"
assert_contains "$nsa_mac"   "LISTEN" "nsa keeps the Internet section (macOS layout)"
assert_not_contains "$nsa_mac" "UNIXROW" \
    "nsa drops the UNIX-domain rows on macOS (regression: the header match was Linux-only)"
assert_contains "$nsa_linux" "LISTEN" "nsa keeps the Internet section (Linux layout)"
assert_not_contains "$nsa_linux" "UNIXROW" "nsa drops the UNIX-domain rows on Linux"

t_finish
