#!/usr/bin/env zsh
# Unit tests for pure helper functions: _urlencode_path, _tmux_emoji_get_command,
# _refresh_cache, and the autoloaded extract/mkcd functions.

source "${0:A:h}/lib.zsh"

# ── _urlencode_path (lib/60-prompt.zsh) ──────────────────────────────
# Source with a stub chevron in PATH so init_prompt is deterministic and
# never touches a real chevrond.
typeset stubdir="$T_SCRATCH/stubbin"
make_stub "$stubdir" chevron "exit 0"

typeset inner="$T_SCRATCH/urlencode_inner.zsh"
cat > "$inner" <<'EOF'
source "$1/.zsh/lib/60-prompt.zsh"
print -r -- "T1=$(_urlencode_path '/tmp/a b')"
print -r -- "T2=$(_urlencode_path '/ok/AZ09._~-/x')"
print -r -- "T3=$(_urlencode_path '/p&q')"
print -r -- "T4=$(_urlencode_path '/p%q')"
print -r -- "T5=$(_urlencode_path '/tmp/café')"
EOF

typeset sb out
sb="$(make_sandbox_home)"
out=$(HOME="$sb" PATH="$stubdir:$PATH" zsh --no-globalrcs -f "$inner" "$ZSH_CONF" 2>&1)
assert_contains "$out" "T1=/tmp/a%20b"      "space percent-encoded"
assert_contains "$out" "T2=/ok/AZ09._~-/x"  "unreserved chars pass through"
assert_contains "$out" "T3=/p%26q"          "ampersand percent-encoded"
assert_contains "$out" "T4=/p%25q"          "percent itself percent-encoded"
assert_contains "$out" "T5=/tmp/caf%C3%A9"  "multibyte UTF-8 encoded per byte"

# ── _tmux_emoji_get_command (lib/75-tmux-emoji.zsh) ──────────────────
# Returns via $REPLY (fork-free preexec hot path), not stdout.
inner="$T_SCRATCH/emoji_inner.zsh"
cat > "$inner" <<'EOF'
source "$1/.zsh/lib/75-tmux-emoji.zsh"
_tmux_emoji_get_command 'sudo make install';              print -r -- "C1=$REPLY"
_tmux_emoji_get_command 'time cargo build --release';     print -r -- "C2=$REPLY"
_tmux_emoji_get_command '/usr/local/bin/python3 -m http.server'; print -r -- "C3=$REPLY"
_tmux_emoji_get_command 'nohup ./run.sh arg';             print -r -- "C4=$REPLY"
_tmux_emoji_get_command 'ls';                             print -r -- "C5=$REPLY"
EOF
out=$(zsh --no-globalrcs -f "$inner" "$ZSH_CONF" 2>&1)
assert_contains "$out" "C1=make"    "strips sudo prefix"
assert_contains "$out" "C2=cargo"   "strips time prefix"
assert_contains "$out" "C3=python3" "strips path"
assert_contains "$out" "C4=run.sh"  "strips nohup + relative path"
assert_contains "$out" "C5=ls"      "bare command unchanged"

# ── _refresh_cache (lib/50-integrations.zsh) ─────────────────────────
# Deterministic mtime ordering via touch -t (no sleeps, no same-second races).
inner="$T_SCRATCH/refresh_inner.zsh"
cat > "$inner" <<'EOF'
export SHELL_CACHE_DIR="$2"
source "$1/.zsh/lib/50-integrations.zsh" 2>/dev/null
cache="$2/probe.cache" inv="$2/probe.inv"
: > "$inv"
_refresh_cache "$cache" 'print -rn -- run1' "$inv"
print -r -- "CREATE=$(<$cache)"
touch -t 200001010000 "$inv"                 # invalidator older than cache
_refresh_cache "$cache" 'print -rn -- run2' "$inv"
print -r -- "STALE=$(<$cache)"
touch -t 200001010000 "$cache"               # cache older ...
touch -t 200101010000 "$inv"                 # ... than invalidator
_refresh_cache "$cache" 'print -rn -- run3' "$inv"
print -r -- "FRESH=$(<$cache)"
_refresh_cache "$cache" 'print -rn -- run4' "/nonexistent/invalidator"
print -r -- "NOINV=$(<$cache)"
# Nix rebuilds change only the resolved target path: every store mtime
# is clamped to the epoch, so the -nt check can never fire (regression:
# tool inits froze at whatever version first populated the cache).
mkdir -p "$2/store-a" "$2/store-b"
: > "$2/store-a/bin"; : > "$2/store-b/bin"
touch -t 197001010000 "$2/store-a/bin" "$2/store-b/bin"
ln -s "$2/store-a/bin" "$2/tool"
_refresh_cache "$2/nix.cache" 'print -rn -- gen1' "$2/tool"
ln -sfn "$2/store-b/bin" "$2/tool"
_refresh_cache "$2/nix.cache" 'print -rn -- gen2' "$2/tool"
print -r -- "NIXSWAP=$(<$2/nix.cache)"
# Failure handling (regression: truncate-then-write left empty caches that
# every later shell sourced forever).
_refresh_cache "$2/fail.cache" 'false' "/nonexistent" 2>/dev/null
print -r -- "FAILRC=$?"
print -r -- "FAILFILES=$(ls "$2" | grep -c fail)"
print -rn -- good > "$2/keep.cache"
touch -t 200001010000 "$2/keep.cache"
: > "$2/keep.inv"
_refresh_cache "$2/keep.cache" 'false' "$2/keep.inv" 2>/dev/null
print -r -- "KEEP=$(<$2/keep.cache)"
EOF
typeset cachedir="$T_SCRATCH/cachework"
mkdir -p "$cachedir"
sb="$(make_sandbox_home)"
out=$(HOME="$sb" zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$cachedir" 2>&1)
assert_contains "$out" "CREATE=run1" "creates cache when missing"
assert_contains "$out" "STALE=run1"  "keeps cache when invalidator is older"
assert_contains "$out" "FRESH=run3"  "rebuilds cache when invalidator is newer"
assert_contains "$out" "NOINV=run3"  "missing invalidator leaves cache alone"
assert_contains "$out" "NIXSWAP=gen2" "nix rebuild (epoch mtimes, retargeted symlink) refreshes"
assert_contains "$out" "FAILRC=1"    "failed generator returns nonzero"
assert_contains "$out" "FAILFILES=0" "failed generator leaves no cache or temp file (regression)"
assert_contains "$out" "KEEP=good"   "failed refresh preserves the old cache (regression)"

# ── _ssh_title_host (lib/80-ssh.zsh) ─────────────────────────────────
# Destination parsing for the tmux window title. Probed via a sandbox
# shell: sourcing 80-ssh.zsh raw would run its agent logic.
typeset sb_ssh
sb_ssh="$(make_sandbox_home)"
out=$(run_sandbox_zsh "$sb_ssh" '
_ssh_title_host host1;                                          print -r -- "S1=$REPLY"
_ssh_title_host -p 2222 user@host2;                             print -r -- "S2=$REPLY"
_ssh_title_host host3 uptime -v;                                print -r -- "S3=$REPLY"
_ssh_title_host -i key -L 8080:localhost:80 user@host4 echo hi; print -r -- "S4=$REPLY"
_ssh_title_host ssh://user@host5:2200/;                         print -r -- "S5=$REPLY"
_ssh_title_host -v;                                             print -r -- "S6=$REPLY"
' 2>/dev/null)
assert_contains "$out" "S1=host1" "bare destination"
assert_contains "$out" "S2=host2" "flag with value before destination (regression: last-arg parse)"
assert_contains "$out" "S3=host3" "remote command after destination ignored"
assert_contains "$out" "S4=host4" "multiple valued flags skipped"
assert_contains "$out" "S5=host5" "ssh:// URL form stripped"
assert_contains "$out" "S6=ssh"   "no destination falls back to plain ssh"

# ── extract (autoloaded function) ────────────────────────────────────
if have tar && have gzip; then
    inner="$T_SCRATCH/extract_inner.zsh"
    cat > "$inner" <<'EOF'
fpath=("$1/.zsh/functions" $fpath)
autoload -Uz extract
cd "$2"
mkdir -p payload out
print hello > payload/file.txt
tar -czf archive.tar.gz payload
cd out
extract ../archive.tar.gz >/dev/null 2>&1
[[ -f payload/file.txt ]] && print -r -- "TARGZ=ok"
cd ..
extract missing.tar.gz >/dev/null 2>&1 || print -r -- "MISSING_RC=$?"
touch odd.xyz
extract odd.xyz >/dev/null 2>&1 || print -r -- "UNKNOWN_RC=$?"
EOF
    typeset workdir="$T_SCRATCH/extractwork"
    mkdir -p "$workdir"
    out=$(zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$workdir" 2>&1)
    assert_contains "$out" "TARGZ=ok"     "extracts .tar.gz"
    assert_contains "$out" "MISSING_RC=1" "missing archive returns 1"
    assert_contains "$out" "UNKNOWN_RC=1" "unknown extension returns 1"
else
    t_skip "extract" "tar/gzip not available"
fi

# ── mkcd (autoloaded function) ───────────────────────────────────────
inner="$T_SCRATCH/mkcd_inner.zsh"
cat > "$inner" <<'EOF'
fpath=("$1/.zsh/functions" $fpath)
autoload -Uz mkcd
cd "$2"
mkcd a/b/c && print -r -- "PWD_TAIL=${PWD#$2}"
mkcd >/dev/null 2>&1 || print -r -- "NOARG_RC=$?"
mkcd x y >/dev/null 2>&1 || print -r -- "TWOARG_RC=$?"
EOF
typeset mkcdwork="$T_SCRATCH/mkcdwork"
mkdir -p "$mkcdwork"
out=$(zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$mkcdwork" 2>&1)
assert_contains "$out" "PWD_TAIL=/a/b/c" "mkcd creates nested dir and cds into it"
assert_contains "$out" "NOARG_RC=1"      "mkcd with no args fails"
assert_contains "$out" "TWOARG_RC=1"     "mkcd with two args fails"

t_finish
