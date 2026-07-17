#!/usr/bin/env zsh
# Cross-cutting invariants: properties that must hold for EVERY boot mode
# and survive any refactor, as opposed to pinned behaviors of specific
# modules (test_startup) or specific past bugs (test_regressions).
#
#   - non-interactive shells are silent, side-effect-free on $HOME, and
#     preserve exit codes (.zshenv's documented contract)
#   - login shells boot clean with the same PATH ordering
#   - `source ~/.zshrc` reaches a fixed point: the 2nd and 3rd re-source
#     must produce IDENTICAL shell state across aliases, options, paths,
#     hooks, functions, zstyles, keybindings, and the environment
#   - PATH/fpath hygiene: absolute, non-empty, duplicate-free entries
#   - no alias/function name collisions (an alias silently shadows the
#     function at the prompt while scripts get the function — divergence)
#   - no function creates an undeclared global (WARN_CREATE_GLOBAL sweep,
#     including the per-command preexec/precmd hot paths)

source "${0:A:h}/lib.zsh"

# Assignments, not bare declarations: zsh prints an already-set exported
# parameter when typeset names it with no value (same gotcha as
# test_atuin_session).
typeset sb='' out='' errf=''
sb="$(make_sandbox_home)"
errf="$T_SCRATCH/inv.err"

# ── Non-interactive shells: silent, exit-code-transparent ────────────
typeset -a envv
_sandbox_env_args "$sb"
envv=("${reply[@]}")

out=$(env -i "${envv[@]}" zsh --no-globalrcs -c 'true' </dev/null 2>&1)
assert_eq "$out" "" "non-interactive boot emits nothing on stdout/stderr"

env -i "${envv[@]}" zsh --no-globalrcs -c 'exit 42' </dev/null 2>/dev/null
assert_eq "$?" "42" "non-interactive shell preserves exit codes"

out=$(env -i "${envv[@]}" zsh --no-globalrcs -l -c 'true' </dev/null 2>&1)
assert_eq "$out" "" "login non-interactive boot emits nothing (.zprofile silent)"

env -i "${envv[@]}" zsh --no-globalrcs -i -c 'exit 42' </dev/null 2>/dev/null
assert_eq "$?" "42" "interactive shell preserves exit codes"

# ── Non-interactive shells: zero filesystem side effects ─────────────
# .zshenv's contract is "fast and side-effect-free"; enforce the second
# half. lstat (-L), not stat: the sandbox's config entries are symlinks
# into the repo and must be fingerprinted as such, not followed.
if zmodload -F zsh/stat b:zstat 2>/dev/null; then
    _home_fingerprint() {
        local f
        local -a lines st
        for f in "$1"/**/*(DNoN); do
            zstat -L -A st +inode +size +mtime -- "$f" 2>/dev/null || continue
            lines+=("${f#$1/}:${(j.:.)st}")
        done
        print -rl -- "${(o)lines[@]}"
    }
    typeset before after
    before="$(_home_fingerprint "$sb")"
    env -i "${envv[@]}" zsh --no-globalrcs -c 'true' </dev/null >/dev/null 2>&1
    env -i "${envv[@]}" zsh --no-globalrcs -l -c 'true' </dev/null >/dev/null 2>&1
    after="$(_home_fingerprint "$sb")"
    if [[ "$before" == "$after" ]]; then
        t_pass "non-interactive boots write nothing under \$HOME"
    else
        t_fail "non-interactive boots write nothing under \$HOME" \
            "$(diff <(print -r -- "$before") <(print -r -- "$after") 2>/dev/null | head -4)"
    fi
else
    t_skip "non-interactive filesystem purity" "zsh/stat unavailable"
fi

# ── First prompt sees $? = 0 ─────────────────────────────────────────
# A module whose last command exits nonzero leaks that status into the
# user's first prompt (red exit-status segments on a fresh shell).
out=$(run_sandbox_zsh "$sb" 'print -r -- "RC=$?"' 2>/dev/null)
assert_contains "$out" "RC=0" "startup leaves \$? = 0 at the first prompt"

# ── Login + interactive boot ─────────────────────────────────────────
out=$(env -i "${envv[@]}" zsh --no-globalrcs -l -i -c \
    'print -r -- "M_LOGIN_END path1=${path[1]}"' </dev/null 2>"$errf")
assert_contains "$out" "M_LOGIN_END"        "login+interactive startup completes"
assert_contains "$out" "path1=$sb/bin"      "login shell keeps \$HOME/bin as PATH head"
typeset -a noise
noise=(${(f)"$(<$errf)"})
noise=(${noise:#*can?t change option: zle*})
if (( ${#noise} == 0 )); then
    t_pass "login+interactive stderr clean"
else
    t_fail "login+interactive stderr clean" "${(j: | :)noise}"
fi

# ── PATH/fpath hygiene, history sizing, namespace collisions ─────────
out=$(run_sandbox_zsh "$sb" '
typeset -a bad
typeset p
for p in "$path[@]"; do
    [[ -z "$p" ]] && bad+=("EMPTY")
    [[ "$p" == /* ]] || bad+=("REL:$p")
done
print -r -- "PATH_BAD=[${(j:, :)bad}]"
print -r -- "PATH_DUPES=$(( ${#path} - ${#${(@u)path}} ))"
bad=()
for p in "$fpath[@]"; do
    [[ -z "$p" ]] && bad+=("EMPTY")
    [[ "$p" == /* ]] || bad+=("REL:$p")
done
print -r -- "FPATH_BAD=[${(j:, :)bad}]"
print -r -- "FPATH_DUPES=$(( ${#fpath} - ${#${(@u)fpath}} ))"
print -r -- "HIST_SIZED=$(( HISTSIZE >= SAVEHIST ? 1 : 0 ))"
typeset -a an fn
an=(${(k)aliases})
fn=(${(k)functions})
print -r -- "COLLIDE=[${(j:, :)${an:*fn}}]"
' 2>/dev/null)
assert_contains "$out" "PATH_BAD=[]"    "every PATH entry is absolute and non-empty"
assert_contains "$out" "PATH_DUPES=0"   "PATH has no duplicate entries"
assert_contains "$out" "FPATH_BAD=[]"   "every fpath entry is absolute and non-empty"
assert_contains "$out" "FPATH_DUPES=0"  "fpath has no duplicate entries"
assert_contains "$out" "HIST_SIZED=1"   "HISTSIZE >= SAVEHIST (trim cushion holds)"
assert_contains "$out" "COLLIDE=[]"     "no name is both an alias and a function"

# ── Reload fixed point: source^2 == source^3 ─────────────────────────
# The FIRST re-source may legitimately differ from the boot state
# (compinit binds its ^X widgets into whichever keymap is main at run
# time, and main flips to viins mid-boot). From then on, re-sourcing must
# be a perfect no-op: identical aliases, options, paths, hooks, function
# and parameter sets, zstyles, keybindings, and environment.
out=$(run_sandbox_zsh "$sb" '
snap() {
    {
        print -r -- "== aliases";   alias -L;  alias -gL;  alias -sL
        print -r -- "== options";   setopt
        print -r -- "== path";      print -rl -- "$path[@]"
        print -r -- "== fpath";     print -rl -- "$fpath[@]"
        print -r -- "== hooks";     print -rl -- "$precmd_functions[@]" "$preexec_functions[@]" "$chpwd_functions[@]"
        print -r -- "== functions"; print -rl -- "${(ko)functions[@]}"
        print -r -- "== params";    print -rl -- "${(ko)parameters[@]}"
        print -r -- "== zstyles";   zstyle -L
        print -r -- "== bindkeys";  bindkey -M viins; bindkey -M vicmd
        print -r -- "== env";       env | sort
    } > "$1"
}
source ~/.zshrc
snap "$HOME/snap2"
source ~/.zshrc
snap "$HOME/snap3"
if diff "$HOME/snap2" "$HOME/snap3" > "$HOME/snap.diff"; then
    print -r -- "FIXED_POINT=yes"
else
    print -r -- "FIXED_POINT=no"
fi
' 2>/dev/null)
if [[ "$out" == *"FIXED_POINT=yes"* ]]; then
    t_pass "source ~/.zshrc reaches a fixed point (2nd == 3rd re-source, full state)"
else
    t_fail "source ~/.zshrc reaches a fixed point (2nd == 3rd re-source, full state)" \
        "$(head -6 "$sb/snap.diff" 2>/dev/null | tr '\n' ' | ')"
fi

# ── Global-creation hygiene (WARN_CREATE_GLOBAL) ─────────────────────
# Boot the full config with the option pre-set (ZDOTDIR wrapper: the
# option must be on BEFORE the first source — it only fires on parameter
# CREATION), then drive the per-command hot paths that -c mode never
# reaches. Third-party init caches create globals by design and are
# filtered by their $SHELL_CACHE_DIR path prefix; everything remaining is
# ours and must be silent. This is the guard against the `for cap in ...`
# class of leak: an undeclared loop variable escaping into every shell.
typeset wcg_sb wrap
wcg_sb="$(make_sandbox_home)"
wrap="$T_SCRATCH/wcg-zdot"
mkdir -p "$wrap"
print -r -- 'source "$HOME/.zshenv"' > "$wrap/.zshenv"
{
    print -r -- 'setopt warn_create_global'
    print -r -- 'source "$HOME/.zshrc"'
} > "$wrap/.zshrc"
_sandbox_env_args "$wcg_sb"
out=$(env -i "${reply[@]}" ZDOTDIR="$wrap" zsh --no-globalrcs -i -c '
detect_platform
has_capability nix
TMUX=fake _tmux_emoji_preexec "not-an-emoji-mapped-command arg"
_tmux_emoji_get_command "sudo make install"
osc7_cwd >/dev/null
_urlencode_path "/tmp/a b" >/dev/null
_ssh_title_host -p 2222 user@host
setup_path
print -r -- M_WCG_END
' </dev/null 2>&1)
assert_contains "$out" "M_WCG_END" "warn_create_global boot completes"
typeset -a leaks
leaks=(${(f)out})
leaks=(${leaks:#*can?t change option: zle*})
leaks=(${(M)leaks:#*created globally*})
leaks=(${leaks:#$wcg_sb/.cache/zsh/*})
# REPLY/reply/match & co are zsh's blessed dynamic-return channels: a
# helper called per its convention writes the CALLER's local, and a bare
# top-level call (as the probes above make) legitimately lands on the
# global. Everything else created in a function is a leak.
leaks=(${leaks:#*parameter (REPLY|reply|match|mbegin|mend|MATCH|MBEGIN|MEND) created*})
if (( ${#leaks} == 0 )); then
    t_pass "no config function creates an undeclared global"
else
    t_fail "no config function creates an undeclared global" "${(j: | :)leaks}"
fi

t_finish
