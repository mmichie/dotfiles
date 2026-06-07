# Test harness library — sourced by each tests/test_*.zsh file.
#
# Conventions:
#   - Each test file is a standalone zsh script run in its own process by
#     run.zsh; its exit code is its failure count.
#   - Assertions print TAP-ish "ok"/"not ok" lines; call t_finish last.
#   - $T_SCRATCH is a per-file temp dir, removed on exit.
#   - Sandboxed shells (run_sandbox_zsh) get a minimal env -i environment and
#     a temp HOME symlinked to the repo's configs/zsh, so tests exercise the
#     repo — not whatever home-manager last deployed — and pass on bare CI.

typeset -g T_LIB_DIR="${0:A:h}"
typeset -g REPO_ROOT="${T_LIB_DIR:h}"
typeset -g ZSH_CONF="$REPO_ROOT/configs/zsh"
typeset -gi _t_pass=0 _t_fail=0 _t_skip=0

# ${...%/} strips macOS TMPDIR's trailing slash — a literal // in scratch
# paths breaks ${PWD#$prefix} comparisons after cd normalizes it away.
typeset -g T_SCRATCH
T_SCRATCH="$(mktemp -d "${${TMPDIR:-/tmp}%/}/zsh-tests.XXXXXXXX")" || exit 99
trap 'rm -rf "$T_SCRATCH"' EXIT

t_pass() { (( _t_pass++ )); print -r -- "  ok - $1"; }
t_fail() {
    (( _t_fail++ ))
    print -r -- "  not ok - $1"
    (( $# > 1 )) && print -r -- "      # $2"
}
t_skip() { (( _t_skip++ )); print -r -- "  ok - $1 # SKIP${2:+ ($2)}"; }

# assert_eq <actual> <expected> <name>
assert_eq() {
    if [[ "$1" == "$2" ]]; then
        t_pass "$3"
    else
        t_fail "$3" "expected ${(qq)2}, got ${(qq)1}"
    fi
}

# assert_contains <haystack> <needle> <name> — literal substring match
assert_contains() {
    if [[ "$1" == *"$2"* ]]; then
        t_pass "$3"
    else
        t_fail "$3" "output does not contain ${(qq)2}"
    fi
}

# assert_not_contains <haystack> <needle> <name>
assert_not_contains() {
    if [[ "$1" != *"$2"* ]]; then
        t_pass "$3"
    else
        t_fail "$3" "output unexpectedly contains ${(qq)2}"
    fi
}

have() { (( $+commands[$1] )); }

t_finish() {
    print -r -- "  ${_t_pass} passed, ${_t_fail} failed, ${_t_skip} skipped"
    exit $(( _t_fail > 250 ? 250 : _t_fail ))
}

# Print the path of a fresh temp HOME wired to the repo's zsh config.
# mktemp, not $RANDOM: this runs inside $(...) subshells, where zsh's RANDOM
# repeats the parent's next value and would collide across calls.
#
# The sandbox gets its own tmp/ (handed to the shell as TMPDIR — keeps any
# tool that prunes its TMPDIR-derived runtime dir away from harness state)
# and 1Password agent-socket symlinks pointing at the dummy listener, so
# lib/80-ssh.zsh takes its earliest exit and never probes or spawns agents.
make_sandbox_home() {
    local h
    h="$(mktemp -d "$T_SCRATCH/home.XXXXXX")" || return 1
    mkdir -p "$h/tmp"
    local f
    for f in .zshrc .zshenv .zprofile .zsh; do
        ln -s "$ZSH_CONF/$f" "$h/$f"
    done
    if [[ -n "$T_AGENT_SOCK" ]]; then
        mkdir -p "$h/Library/Group Containers/2BUA8C4S2C.com.1password/t" "$h/.1password"
        ln -s "$T_AGENT_SOCK" "$h/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
        ln -s "$T_AGENT_SOCK" "$h/.1password/agent.sock"
    fi
    print -r -- "$h"
}

# Dummy listening unix socket so sourcing lib/80-ssh.zsh sees a "live" agent
# at $SSH_AUTH_SOCK and never spawns a real ssh-agent from a test run.
# The listener fd stays open for the life of the test process.
typeset -g T_AGENT_SOCK=""
make_agent_sock() {
    [[ -n "$T_AGENT_SOCK" ]] && return 0
    zmodload zsh/net/socket 2>/dev/null || return 1
    zsocket -l "$T_SCRATCH/agent.sock" 2>/dev/null || return 1
    T_AGENT_SOCK="$T_SCRATCH/agent.sock"
}

# Stub ssh-agent/ssh-add so lib/80-ssh.zsh can never spawn a real agent out
# of a test run. Belt to make_agent_sock's braces: where zsocket cannot bind
# (the darwin nix build sandbox denies it), restart_ssh_agent falls through
# to these no-ops instead of real binaries.
typeset -g T_AGENT_STUBS=""
_make_agent_stubs() {
    [[ -n "$T_AGENT_STUBS" ]] && return 0
    T_AGENT_STUBS="$T_SCRATCH/agent-stubs"
    make_stub "$T_AGENT_STUBS" ssh-agent
    make_stub "$T_AGENT_STUBS" ssh-add
}

# Build the env(1) assignment vector for a sandboxed shell into $reply.
# Single source of truth for the sandbox environment — used by
# run_sandbox_zsh and by tests that need a custom zsh invocation (xtrace).
_sandbox_env_args() {
    local home="$1"
    reply=(
        HOME="$home"
        PATH="$T_AGENT_STUBS:$PATH"
        TERM=dumb
        USER="${USER:-tester}"
        TMPDIR="$home/tmp"
        INFLUX_SHOWN=1
        CHEVRON_DISABLE=1
    )
    [[ -n "$T_AGENT_SOCK" ]] && reply+=(SSH_AUTH_SOCK="$T_AGENT_SOCK")
}

# run_sandbox_zsh <home> <command-string> [VAR=val ...]
# Interactive zsh against a sandbox HOME with a minimal controlled env.
# --no-globalrcs keeps /etc/zsh* (nix-darwin, path_helper) out of the picture;
# INFLUX_SHOWN + non-login suppresses the banner/tips block.
# Note: do not pass PATH=... as an extra — macOS env(1) serves the FIRST of
# duplicate bindings to getenv, so the override is silently ignored. Prepend
# to $path inside the command string instead.
run_sandbox_zsh() {
    local home="$1" cmd="$2"
    shift 2
    _sandbox_env_args "$home"
    # </dev/null: under pty-allocating callers (lefthook) an inherited tty
    # stdin lets startup tools negotiate with the terminal (cursor queries,
    # graphics probes) and cross-talk between concurrent boots.
    env -i "${reply[@]}" "$@" zsh --no-globalrcs -i -c "$cmd" </dev/null
}

# make_stub <dir> <name> [body]
# Create an executable /bin/sh stub. Default body is "exit 0".
make_stub() {
    local dir="$1" name="$2"
    shift 2
    mkdir -p "$dir"
    {
        print -r -- "#!/bin/sh"
        if (( $# )); then
            print -r -- "$@"
        else
            print -r -- "exit 0"
        fi
    } > "$dir/$name"
    chmod +x "$dir/$name"
}

# Initialize the shared agent infrastructure ONCE, in the main test process.
# Calling these lazily from inside $(...) captures would set the globals and
# hold the listener fd in a throwaway subshell: the socket file outlives it,
# every later bind fails with "address in use", and sandboxes silently lose
# their agent shielding.
make_agent_sock
_make_agent_stubs
