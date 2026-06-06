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
EOF

typeset sb out
sb="$(make_sandbox_home)"
out=$(HOME="$sb" PATH="$stubdir:$PATH" zsh --no-globalrcs -f "$inner" "$ZSH_CONF" 2>&1)
assert_contains "$out" "T1=/tmp/a%20b"      "space percent-encoded"
assert_contains "$out" "T2=/ok/AZ09._~-/x"  "unreserved chars pass through"
assert_contains "$out" "T3=/p%26q"          "ampersand percent-encoded"
assert_contains "$out" "T4=/p%25q"          "percent itself percent-encoded"

# ── _tmux_emoji_get_command (lib/75-tmux-emoji.zsh) ──────────────────
inner="$T_SCRATCH/emoji_inner.zsh"
cat > "$inner" <<'EOF'
source "$1/.zsh/lib/75-tmux-emoji.zsh"
print -r -- "C1=$(_tmux_emoji_get_command 'sudo make install')"
print -r -- "C2=$(_tmux_emoji_get_command 'time cargo build --release')"
print -r -- "C3=$(_tmux_emoji_get_command '/usr/local/bin/python3 -m http.server')"
print -r -- "C4=$(_tmux_emoji_get_command 'nohup ./run.sh arg')"
print -r -- "C5=$(_tmux_emoji_get_command 'ls')"
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
EOF
typeset cachedir="$T_SCRATCH/cachework"
mkdir -p "$cachedir"
sb="$(make_sandbox_home)"
out=$(HOME="$sb" zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$cachedir" 2>&1)
assert_contains "$out" "CREATE=run1" "creates cache when missing"
assert_contains "$out" "STALE=run1"  "keeps cache when invalidator is older"
assert_contains "$out" "FRESH=run3"  "rebuilds cache when invalidator is newer"
assert_contains "$out" "NOINV=run3"  "missing invalidator leaves cache alone"

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
