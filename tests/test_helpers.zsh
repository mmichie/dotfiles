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
# Rebuild detection: the generator command reads $gen, whose content changes
# between calls — but $gen is never an invalidator, so cache content moves
# ONLY when _refresh_cache actually re-ran the command. The command string
# stays constant across the no-rebuild probes because it is itself part of
# the staleness fingerprint (pinned by CMDCHANGE below).
inner="$T_SCRATCH/refresh_inner.zsh"
cat > "$inner" <<'EOF'
export SHELL_CACHE_DIR="$2"
source "$1/.zsh/lib/50-integrations.zsh" 2>/dev/null
cache="$2/probe.cache" inv="$2/probe.inv" gen="$2/probe.gen"
cmd="cat $gen"
: > "$inv"
print -rn -- run1 > "$gen"
_refresh_cache "$cache" "$cmd" "$inv"
print -r -- "CREATE=$(<$cache)"
print -rn -- run2 > "$gen"
touch -t 200001010000 "$inv"                 # invalidator older than cache
_refresh_cache "$cache" "$cmd" "$inv"
print -r -- "STALE=$(<$cache)"
touch -t 200001010000 "$cache"               # cache older ...
touch -t 200101010000 "$inv"                 # ... than invalidator
_refresh_cache "$cache" "$cmd" "$inv"
print -r -- "FRESH=$(<$cache)"
print -rn -- run3 > "$gen"
_refresh_cache "$cache" "$cmd" "/nonexistent/invalidator"
print -r -- "NOINV=$(<$cache)"
# The command string is fingerprinted (line 1 of the .dep sidecar): an
# edited init line (vivid theme, atuin flags) must rebuild even though
# no invalidator path or mtime moved.
_refresh_cache "$cache" "$cmd # edited" "$inv"
print -r -- "CMDCHANGE=$(<$cache)"
print -rn -- run4 > "$gen"
_refresh_cache "$cache" "$cmd # edited" "$inv"
print -r -- "CMDSTABLE=$(<$cache)"
# Nix rebuilds change only the resolved target path: every store mtime
# is clamped to the epoch, so the -nt check can never fire (regression:
# tool inits froze at whatever version first populated the cache).
mkdir -p "$2/store-a" "$2/store-b"
: > "$2/store-a/bin"; : > "$2/store-b/bin"
touch -t 197001010000 "$2/store-a/bin" "$2/store-b/bin"
ln -s "$2/store-a/bin" "$2/tool"
print -rn -- gen1 > "$gen"
_refresh_cache "$2/nix.cache" "$cmd" "$2/tool"
print -rn -- gen2 > "$gen"
ln -sfn "$2/store-b/bin" "$2/tool"
_refresh_cache "$2/nix.cache" "$cmd" "$2/tool"
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
assert_contains "$out" "CREATE=run1"    "creates cache when missing"
assert_contains "$out" "STALE=run1"     "keeps cache when invalidator is older"
assert_contains "$out" "FRESH=run2"     "rebuilds cache when invalidator is newer"
assert_contains "$out" "NOINV=run2"     "missing invalidator leaves cache alone"
assert_contains "$out" "CMDCHANGE=run3" "edited generating command forces a rebuild"
assert_contains "$out" "CMDSTABLE=run3" "unchanged command after a rebuild stays cached"
assert_contains "$out" "NIXSWAP=gen2"   "nix rebuild (epoch mtimes, retargeted symlink) refreshes"
assert_contains "$out" "FAILRC=1"       "failed generator returns nonzero"
assert_contains "$out" "FAILFILES=0"    "failed generator leaves no cache or temp file (regression)"
assert_contains "$out" "KEEP=good"      "failed refresh preserves the old cache (regression)"

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
_ssh_title_host -B en0 user@host7;                              print -r -- "S7=$REPLY"
' 2>/dev/null)
assert_contains "$out" "S1=host1" "bare destination"
assert_contains "$out" "S2=host2" "flag with value before destination (regression: last-arg parse)"
assert_contains "$out" "S3=host3" "remote command after destination ignored"
assert_contains "$out" "S4=host4" "multiple valued flags skipped"
assert_contains "$out" "S5=host5" "ssh:// URL form stripped"
assert_contains "$out" "S6=ssh"   "no destination falls back to plain ssh"
assert_contains "$out" "S7=host7" "-B bind-interface value skipped (regression: titled the window en0)"

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

# ── Hostile-input corpus: preexec/prompt hot-path helpers ─────────────
# These run on every keystroke-adjacent event; the property under test is
# not a specific mapping but "never errors, never writes to stderr, always
# terminates" for inputs a user can realistically produce (pasted
# multi-line commands, unicode, flag soup).
inner="$T_SCRATCH/fuzz_emoji_inner.zsh"
cat > "$inner" <<'EOF'
source "$1/.zsh/lib/75-tmux-emoji.zsh"
typeset -a corpus
corpus=(
    ''
    '     '
    $'\t\t'
    $'multi\nline\ncommand'
    'a;b|c&&d'
    '"quoted arg" '"'"'single'"'"''
    'sudo'
    '/path with spaces/tool --flag'
    'привет мир'
    '🚀 launch'
)
corpus+=("${(l:4096::x:):-}")   # 4KB single token
typeset -i failures=0
typeset input
for input in "${corpus[@]}"; do
    local REPLY
    if ! _tmux_emoji_get_command "$input" 2>>"$2"; then
        (( failures++ ))
    fi
    (( ${+REPLY} )) || (( failures++ ))
done
print -r -- "EMOJI_FUZZ_FAILURES=$failures"
print -r -- "EMOJI_FUZZ_N=${#corpus}"
EOF
typeset fuzzerr="$T_SCRATCH/fuzz_emoji.err"
: > "$fuzzerr"
out=$(zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$fuzzerr" 2>&1)
assert_contains "$out" "EMOJI_FUZZ_FAILURES=0" "emoji command parser survives hostile corpus"
assert_contains "$out" "EMOJI_FUZZ_N=11"       "emoji fuzz corpus fully executed"
assert_eq "$(<$fuzzerr)" "" "emoji command parser silent on stderr across corpus"

# ── _urlencode_path: charset + roundtrip properties ───────────────────
# Whatever the input, the output must contain only unreserved chars, /,
# and %XX escapes — and decoding must reproduce the input byte-for-byte
# (OSC 7 consumers hard-require this).
inner="$T_SCRATCH/fuzz_url_inner.zsh"
cat > "$inner" <<'EOF'
source "$1/.zsh/lib/60-prompt.zsh" 2>/dev/null
_t_urldecode() {
    local s="$1" out='' c
    local -i i code
    local LC_ALL=C
    setopt localoptions no_multibyte
    for (( i=1; i<=${#s}; i++ )); do
        c="${s[i]}"
        if [[ "$c" == '%' ]]; then
            code=$(( 16#${s[i+1,i+2]} ))
            c="${(#)code}"
            (( i += 2 ))
        fi
        out+="$c"
    done
    print -rn -- "$out"
}
typeset -a corpus
corpus=(
    '/tmp/a b'
    '/tmp/café/日本語'
    '/p%q'
    $'/new\nline'
    '/already%20encoded'
    '/~user/.hidden dir/x-y_z'
    '/quotes "double" and '"'"'single'"'"''
    '/emoji 🚀/dir'
    ''
)
typeset -i bad_charset=0 bad_roundtrip=0
typeset p enc dec
for p in "${corpus[@]}"; do
    enc="$(_urlencode_path "$p")"
    [[ "$enc" != *[^A-Za-z0-9._~/%-]* ]] || (( bad_charset++ ))
    dec="$(_t_urldecode "$enc")"
    [[ "$dec" == "$p" ]] || { (( bad_roundtrip++ )); print -r -- "RT_FAIL: ${(qq)p} -> ${(qq)enc} -> ${(qq)dec}" }
done
print -r -- "URL_BAD_CHARSET=$bad_charset"
print -r -- "URL_BAD_ROUNDTRIP=$bad_roundtrip"
EOF
out=$(zsh --no-globalrcs -f "$inner" "$ZSH_CONF" 2>&1)
assert_contains "$out" "URL_BAD_CHARSET=0"   "urlencode emits only unreserved chars and %XX escapes"
assert_contains "$out" "URL_BAD_ROUNDTRIP=0" "urlencode/decode roundtrips byte-for-byte"

# ── _ssh_title_host: flag-soup corpus ─────────────────────────────────
# Property: always returns 0 with a non-empty REPLY (the title is used
# unconditionally), plus exact answers where the parse is unambiguous.
typeset sb_soup
sb_soup="$(make_sandbox_home)"
out=$(run_sandbox_zsh "$sb_soup" '
typeset -i soup_failures=0
probe() {
    local REPLY
    _ssh_title_host "$@" || (( soup_failures++ ))
    [[ -n "$REPLY" ]] || (( soup_failures++ ))
    print -r -- "$REPLY"
}
print -r -- "P1=$(probe -o StrictHostKeyChecking=no user@target)"
print -r -- "P2=$(probe -- host-after-separator)"
print -r -- "P3=$(probe -v -A -4)"
print -r -- "P4=$(probe -p2222 joined-flag-host)"
print -r -- "P5=$(probe -i ~/.ssh/id -J jump1,jump2 -L 80:x:80 real-host tail cmd)"
print -r -- "P6=$(probe --)"
print -r -- "P7=$(probe "" )"
print -r -- "SOUP_FAILURES=$soup_failures"
' 2>/dev/null)
assert_contains "$out" "P1=target"               "-o valued flag skipped to destination"
assert_contains "$out" "P2=host-after-separator" "-- separator honored"
assert_contains "$out" "P3=ssh"                  "flags-only argv falls back to ssh"
assert_contains "$out" "P4=joined-flag-host"     "joined -p2222 skipped"
assert_contains "$out" "P5=real-host"            "multi-flag soup lands on the destination"
assert_contains "$out" "P6=ssh"                  "bare -- falls back to ssh"
assert_contains "$out" "SOUP_FAILURES=0"         "ssh title parser never errors, never returns empty"

# ── _ls_gnu_to_eza (lib/35-ls.zsh) ───────────────────────────────────
# Pure translator: GNU short-flag clusters -> eza argv in $reply, rc 1 for
# anything unmapped (dispatcher then runs real ls). Sort directions pinned
# against observed GNU ls output: -t/-S list newest/largest FIRST while eza
# sorts ascending, so the reverse bit is (GNU-descending XOR r).
inner="$T_SCRATCH/lsflags_inner.zsh"
cat > "$inner" <<'EOF'
source "$1/.zsh/lib/00-platform.zsh" 2>/dev/null
source "$1/.zsh/lib/35-ls.zsh" 2>/dev/null
probe() {
    local -a reply
    if _ls_gnu_to_eza "$@"; then
        print -r -- "OK ${(j: :)reply}"
    else
        print -r -- "FALLBACK"
    fi
}
print -rn -- "L1=";  probe -altr
print -rn -- "L2=";  probe -alrt
print -rn -- "L3=";  probe -lt
print -rn -- "L4=";  probe -ltr somedir
print -rn -- "L5=";  probe -lS
print -rn -- "L6=";  probe -lSr
print -rn -- "L7=";  probe -lha
print -rn -- "L8=";  probe -lG
print -rn -- "L9=";  probe --git-ignore
print -rn -- "L10="; probe -l -- -t
print -rn -- "L11="; probe
EOF
out=$(zsh --no-globalrcs -f "$inner" "$ZSH_CONF" 2>&1)
assert_contains "$out" "L1=OK --all --long --sort=modified"           "-altr translates (oldest first)"
assert_contains "$out" "L2=OK --all --long --sort=modified"           "-alrt permutation translates identically"
assert_contains "$out" "L3=OK --long --sort=modified --reverse"       "-lt means newest first (reverse for eza)"
assert_contains "$out" "L4=OK --long --sort=modified -- somedir"      "paths survive behind a -- separator"
assert_contains "$out" "L5=OK --long --sort=size --reverse"           "-lS means largest first"
assert_contains "$out" "L6=OK --long --sort=size"                     "-lSr means smallest first"
assert_contains "$out" "L7=OK --long --all"                           "-h dropped (eza -h means header, sizes already human)"
assert_contains "$out" "L8=FALLBACK"                                  "unmapped letter falls back to real ls"
assert_contains "$out" "L9=OK --git-ignore"                           "long options pass through to eza"
assert_contains "$out" "L10=OK --long -- -t"                          "args after -- are paths, not flags"
assert_contains "$out" "L11=OK"                                       "bare invocation translates to bare eza"

t_finish
