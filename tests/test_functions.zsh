#!/usr/bin/env zsh
# Behaviour of the autoloaded user commands in configs/zsh/.zsh/functions
# that had no test: what each one runs, with which arguments, and what it
# prints or returns on its error paths. Every external program a function
# reaches is a stub on PATH (docker, open, curl, op, the compressors, tmux,
# ...), so nothing here prunes, opens, uploads or fetches anything.
#
# Each probe autoloads the function into a `zsh -f` script and narrows PATH
# inside that script, after zsh itself has been found.

source "${0:A:h}/lib.zsh"

typeset inner='' out='' work='' log=''

# link_tools <dir> <cmd...>: symlink real commands into a directory used as a
# narrowed PATH. Fails when one is missing, so callers can skip.
link_tools() {
    local dir="$1" cmd
    shift
    mkdir -p "$dir"
    for cmd in "$@"; do
        (( $+commands[$cmd] )) || return 1
        ln -sf "${commands[$cmd]}" "$dir/$cmd"
    done
}

# ── docker_cleanup ────────────────────────────────────────────────────
# The confirmation reads one key from the terminal. A function stands in for
# the read builtin so the answer is scripted and nothing waits on a tty.
typeset dockerbin="$T_SCRATCH/dockerbin"
make_stub "$dockerbin" docker 'printf "docker %s\n" "$*" >> "$DOCKER_LOG"
[ -n "$DOCKER_OLD" ] && [ "$*" = "volume prune --all -f" ] && exit 1
exit 0'
inner="$T_SCRATCH/docker_cleanup.zsh"
cat > "$inner" <<'EOF'
fpath=("$1/.zsh/functions" $fpath)
autoload -Uz docker_cleanup
path=("$2" $path)
read() { [[ "$ANSWER" == y ]]; }
docker_cleanup $3
print -r -- "RC=$?"
EOF
log="$T_SCRATCH/docker.log"
: > "$log"
out=$(DOCKER_LOG="$log" zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$dockerbin" -y 2>&1)
assert_contains "$out" "RC=0" "docker_cleanup -y succeeds"
assert_eq "$(<"$log")" $'docker system prune -af\ndocker volume prune --all -f' \
    "docker_cleanup -y prunes the system, then named volumes too (--all)"
: > "$log"
DOCKER_LOG="$log" zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$dockerbin" --yes >/dev/null 2>&1
assert_contains "$(<"$log")" "docker system prune -af" "docker_cleanup --yes skips the prompt as well"
: > "$log"
DOCKER_LOG="$log" DOCKER_OLD=1 zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$dockerbin" -y >/dev/null 2>&1
assert_eq "$(<"$log")" $'docker system prune -af\ndocker volume prune --all -f\ndocker volume prune -f' \
    "a daemon without volume prune --all gets plain volume prune"
: > "$log"
out=$(DOCKER_LOG="$log" ANSWER=n zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$dockerbin" 2>&1)
assert_contains "$out" "ALL unused volumes (including named)" "without -y, docker_cleanup says what it will delete"
assert_contains "$out" "RC=1" "a declined prompt returns 1"
assert_eq "$(<"$log")" "" "a declined prompt runs no docker command"
out=$(DOCKER_LOG="$log" ANSWER=y zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$dockerbin" 2>&1)
assert_contains "$out" "RC=0" "an accepted prompt prunes"
assert_contains "$(<"$log")" "docker system prune -af" "an accepted prompt runs the prune"

# ── extract: which tool each archive type goes to ─────────────────────
# test_helpers.zsh extracts a real .tar.gz. Here every extractor is a stub,
# so each case arm is pinned, ordering included: a.tar.bz2 must reach tar,
# not the *.bz2 arm below it.
typeset extractbin="$T_SCRATCH/extractbin" tool=''
for tool in tar bunzip2 unrar gunzip unzip uncompress 7z; do
    make_stub "$extractbin" "$tool" "printf '%s %s\\n' $tool \"\$*\""
done
work="$T_SCRATCH/extractwork"
mkdir -p "$work"
inner="$T_SCRATCH/extract.zsh"
cat > "$inner" <<'EOF'
fpath=("$1/.zsh/functions" $fpath)
autoload -Uz extract
path=("$2")
cd "$3"
for f in a.tar.bz2 a.tar.gz a.bz2 a.rar a.gz a.tar a.tbz2 a.tgz a.zip a.Z a.7z; do
    : > "$f"
    print -rn -- "$f => "
    extract "$f"
done
EOF
out=$(zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$extractbin" "$work" 2>&1)
typeset expected=''
for expected in \
    'a.tar.bz2 => tar xjf a.tar.bz2' 'a.tar.gz => tar xzf a.tar.gz' \
    'a.bz2 => bunzip2 a.bz2' 'a.rar => unrar x a.rar' 'a.gz => gunzip a.gz' \
    'a.tar => tar xf a.tar' 'a.tbz2 => tar xjf a.tbz2' 'a.tgz => tar xzf a.tgz' \
    'a.zip => unzip a.zip' 'a.Z => uncompress a.Z' 'a.7z => 7z x a.7z'
do
    assert_contains "$out" "$expected" "extract dispatches ${expected%% =>*} to ${${expected#*=> }% *}"
done

# ── fs: GNU or BSD du ─────────────────────────────────────────────────
# fs probes `du -b` once: GNU du takes it (apparent sizes in bytes), BSD du
# rejects it. The stub answers the probe as told and echoes the real call.
typeset dubin="$T_SCRATCH/dubin"
make_stub "$dubin" du 'if [ "$1" = -b ]; then exit "$DU_B_RC"; fi
printf "du %s\n" "$*"'
work="$T_SCRATCH/fswork"
mkdir -p "$work"
: > "$work/.hidden"
: > "$work/visible"
inner="$T_SCRATCH/fs.zsh"
cat > "$inner" <<'EOF'
fpath=("$1/.zsh/functions" $fpath)
autoload -Uz fs
path=("$2")
cd "$3"
fs named
fs
EOF
out=$(DU_B_RC=0 zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$dubin" "$work" 2>&1)
assert_contains "$out" "du -sbh -- named" "fs passes its arguments to GNU du with -sbh"
assert_contains "$out" "du -sbh -- .hidden ./visible" "fs with no arguments sizes every entry, dotfiles included"
out=$(DU_B_RC=1 zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$dubin" "$work" 2>&1)
assert_contains "$out" "du -sh -- named" "fs falls back to -sh where du has no -b (BSD)"
assert_contains "$out" "du -sh -- .hidden ./visible" "the BSD fallback also covers the no-argument form"

# ── gz: size report and usage ─────────────────────────────────────────
if have gzip; then
    inner="$T_SCRATCH/gz.zsh"
    cat > "$inner" <<'EOF'
fpath=("$1/.zsh/functions" $fpath)
autoload -Uz gz
print -rn -- ${(l:1000::a:)} > "$2/thousand"
gz "$2/thousand"
gz "$2/missing" 2>&1
print -r -- "MISSING_RC=$?"
EOF
    work="$T_SCRATCH/gzsizes"
    mkdir -p "$work"
    out=$(zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$work" 2>&1)
    assert_contains "$out" "orig: 1000 bytes" "gz reports the original size"
    if [[ "$out" == *$'\n'"gzip: "<->" bytes ("<->.<->"%)"* ]]; then
        t_pass "gz reports the gzipped size and its percentage"
    else
        t_fail "gz reports the gzipped size and its percentage" "$out"
    fi
    assert_contains "$out" "Usage: gz <file>" "gz explains itself when the file is missing"
    assert_contains "$out" "MISSING_RC=1" "gz on a missing file returns 1"
else
    t_skip "gz size report" "gzip not available"
fi

# ── loadenv ───────────────────────────────────────────────────────────
# A wrapper over _parse_env_file (lib/10-environment.zsh, tested in
# test_parse_env.zsh) for the .env in the current directory, with the
# modules sourced in .zshrc's order.
inner="$T_SCRATCH/loadenv.zsh"
cat > "$inner" <<'EOF'
source "$1/.zsh/lib/00-platform.zsh"
source "$1/.zsh/lib/05-options.zsh"
source "$1/.zsh/lib/10-environment.zsh"
fpath=("$1/.zsh/functions" $fpath)
autoload -Uz loadenv
cd "$2"
loadenv
print -r -- "MISSING_RC=$?"
print -rl -- 'GREETING="hello there"' 'TOKEN=abc' > .env
loadenv
print -r -- "LOADED_RC=$? GREETING=$GREETING TOKEN=$TOKEN"
print -rl -- 'key=lowercase' 'value=literal' 'verbose=0' 'AFTER=works' > .env
loadenv
command env | grep -E '^(key|value|verbose|AFTER)='
_parse_env_file() { return 13; }
loadenv
print -r -- "FAILED_LOAD_RC=$?"
EOF
work="$T_SCRATCH/loadenvwork"
mkdir -p "$work"
typeset envhome="$(make_sandbox_home)"
out=$(HOME="$envhome" zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$work" 2>&1)
assert_contains "$out" "Error: .env file does not exist in the current directory." "loadenv without a .env says so"
assert_contains "$out" "MISSING_RC=1" "loadenv without a .env returns 1"
assert_contains "$out" $'Loading environment variables:\nLoaded: GREETING\nLoaded: TOKEN\nAll environment variables loaded successfully.' \
    "loadenv names each variable it loads"
assert_contains "$out" "LOADED_RC=0 GREETING=hello there TOKEN=abc" "loadenv exports the values, quotes stripped"
for assignment in key=lowercase value=literal verbose=0 AFTER=works; do
    assert_contains "$out" $'\n'"$assignment"$'\n' "loadenv exports $assignment"
done
assert_contains "$out" $'Loading environment variables:\nLoaded: key\nLoaded: value\nLoaded: verbose\nLoaded: AFTER' \
    "loadenv logs assignments even if one is named verbose"
assert_not_contains "${out##*AFTER=works}" "All environment variables loaded successfully." \
    "loadenv does not report success when parsing fails"
assert_contains "$out" "FAILED_LOAD_RC=13" "loadenv propagates parser failures"

# ── hgrep, remember, recalls: usage and empty states ──────────────────
inner="$T_SCRATCH/usage.zsh"
cat > "$inner" <<'EOF'
fpath=("$1/.zsh/functions" $fpath)
autoload -Uz hgrep remember recalls
hgrep
print -r -- "HGREP_RC=$?"
remember
print -r -- "REMEMBER_RC=$?"
recalls
print -r -- "RECALLS_EMPTY_RC=$?"
print -r -- 'git log --oneline' > "$HOME/.important_commands"
recalls
rm "$HOME/.important_commands"
mkdir "$HOME/.important_commands"
remember echo example
print -r -- "FAILED_SAVE_RC=$?"
EOF
typeset usagehome="$T_SCRATCH/usagehome"
mkdir -p "$usagehome"
out=$(HOME="$usagehome" zsh --no-globalrcs -f "$inner" "$ZSH_CONF" 2>&1)
assert_contains "$out" "Usage: hgrep <pattern>" "hgrep with no pattern prints its usage"
assert_contains "$out" "HGREP_RC=1" "hgrep with no pattern returns 1"
assert_contains "$out" "Usage: remember <command>" "remember with nothing to save prints its usage"
assert_contains "$out" "REMEMBER_RC=1" "remember with nothing to save returns 1"
assert_contains "$out" "No saved commands yet." "recalls says so before anything was remembered"
assert_contains "$out" "RECALLS_EMPTY_RC=0" "an empty recalls is not an error"
assert_contains "$out" "git log --oneline" "recalls with no pattern lists every saved command"
assert_contains "$out" "FAILED_SAVE_RC=1" "remember returns failure when it cannot append"
assert_not_contains "$out" "Command saved" "remember does not report success after a failed write"

# ── thin wrappers: the exact command each one runs ────────────────────
typeset wrapbin="$T_SCRATCH/wrapbin"
for tool in curl open python3 ssh; do
    make_stub "$wrapbin" "$tool" "printf '%s %s\\n' $tool \"\$*\""
done
make_stub "$wrapbin" tmux 'printf "tmux TMUX=[%s] %s\n" "$TMUX" "$*"'
make_stub "$wrapbin" tree 'printf "tree %s\n" "$*"'
# less passes its input through, so the probe sees both ends of tre's pipe.
make_stub "$wrapbin" less 'printf "less %s\n" "$*"
while IFS= read -r line; do printf "%s\n" "$line"; done'
make_stub "$wrapbin" zoxide 'if [ "$1 $2" = "query --list" ]; then
    i=1
    while [ "$i" -le 12 ]; do printf "/dir%s\n" "$i"; i=$((i + 1)); done
fi'
inner="$T_SCRATCH/wrappers.zsh"
cat > "$inner" <<'EOF'
fpath=("$1/.zsh/functions" $fpath)
autoload -Uz http_headers o server sshtunnel tnest tre ztop
path=("$2" $path)
http_headers https://example.invalid/
o
o one two
server
server 9001
sshtunnel jumphost 5432 15432
TMUX=/tmp/outer,1,0 tnest -d
tre somedir
print -r -- "ZTOP_DEFAULT=${$(ztop | wc -l)//[[:space:]]/}"
print -r -- "ZTOP_THREE=${(j:,:)${(f)$(ztop 3)}}"
EOF
out=$(zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$wrapbin" 2>&1)
assert_contains "$out" "curl -I -L https://example.invalid/" "http_headers asks curl for headers, following redirects"
assert_contains "$out" "open ." "o with no argument opens the current directory"
assert_contains "$out" "open one two" "o passes its arguments to open"
assert_contains "$out" "python3 -m http.server 8000" "server defaults to port 8000"
assert_contains "$out" "python3 -m http.server 9001" "server takes a port"
assert_contains "$out" "ssh jumphost -L 15432:localhost:5432" "sshtunnel forwards the local port to the remote one"
assert_contains "$out" "tmux TMUX=[] -L nested new-session -A -s nested -d" \
    "tnest starts or attaches the nested server with TMUX cleared"
assert_contains "$out" "less -FRNX" "tre pages through less"
assert_contains "$out" "tree -aC -I .git|node_modules|bower_components --dirsfirst somedir" \
    "tre lists hidden files and skips VCS and dependency trees"
assert_contains "$out" $'ZTOP_DEFAULT=10\n' "ztop shows ten directories by default"
assert_contains "$out" "ZTOP_THREE=/dir1,/dir2,/dir3" "ztop takes a count"

# ── man: with and without bat ─────────────────────────────────────────
# With bat, man's output is cleaned of escape sequences and overstrikes, then
# highlighted. Without it, less gets colour through LESS_TERMCAP_*.
typeset manbat="$T_SCRATCH/manbat" mannobat="$T_SCRATCH/mannobat"
make_stub "$manbat" man 'if [ "$1" = missing ]; then exit 16; fi
printf "man %s\n" "$*"
printf "\033[1mBOLD\033[0m O\010Over\n"'
make_stub "$manbat" bat 'printf "bat %s\n" "$*"
while IFS= read -r line; do printf "%s\n" "$line"; done'
typeset realperl=0
if link_tools "$manbat" perl; then
    realperl=1
else
    make_stub "$manbat" perl 'while IFS= read -r line; do printf "%s\n" "$line"; done'
fi
make_stub "$mannobat" man 'printf "man %s md=%s\n" "$*" "$LESS_TERMCAP_md"'
inner="$T_SCRATCH/man.zsh"
cat > "$inner" <<'EOF'
fpath=("$1/.zsh/functions" $fpath)
autoload -Uz man
path=("$2")
man ls
man missing
print -r -- "MISSING_MAN_RC=$?"
EOF
out=$(zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$manbat" 2>&1)
assert_contains "$out" "bat --color=always -l man -p" "man pipes through bat as a man page"
assert_contains "$out" "man ls" "man runs the real man with the same arguments"
assert_contains "$out" "MISSING_MAN_RC=16" "man propagates lookup failures through bat"
if (( realperl )); then
    assert_contains "$out" "BOLD Over" "man strips escape sequences and overstrikes before bat"
else
    t_skip "man strips escape sequences and overstrikes before bat" "perl not available"
fi
if link_tools "$mannobat" env; then
    out=$(zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$mannobat" 2>&1)
    assert_contains "$out" "man ls md="$'\e[1;36m' "without bat, man colours headings through LESS_TERMCAP_md"
else
    t_skip "man without bat" "env not available"
fi

# ── targz: compressor choice ──────────────────────────────────────────
# zopfli when present (inputs under 50 MB), else pigz, else gzip. The stubs
# leave a .gz the way each real tool does: zopfli keeps its input, pigz
# removes it.
typeset targztools="$T_SCRATCH/targztools"
if link_tools "$targztools" tar rm gzip mktemp ln; then
    typeset zopflibin="$T_SCRATCH/zopflibin" pigzbin="$T_SCRATCH/pigzbin" nobin="$T_SCRATCH/nocompressor"
    make_stub "$zopflibin" zopfli 'case "$2" in
    */race.tar) printf winner > "${2%/.targz.*}/race.tar.gz" ;;
esac
printf z > "$2.gz"'
    make_stub "$pigzbin" pigz 'printf z > "$2.gz" && rm -f "$2"'
    mkdir -p "$nobin"
    inner="$T_SCRATCH/targz.zsh"
    cat > "$inner" <<'EOF'
fpath=("$1/.zsh/functions" $fpath)
autoload -Uz targz
path=("$2" "$3")
cd "$4"
targz 2>&1
print -r -- "USAGE_RC=$?"
targz payload/ 2>/dev/null
print -r -- "RC=$?"
[[ -s payload.tar.gz ]] && print -r -- GZ_WRITTEN
[[ "$(<payload.tar)" == original ]] && print -r -- TAR_PRESERVED
zstat -A before +inode -- payload.tar.gz
targz payload >/dev/null 2>&1
print -r -- "COLLISION_RC=$?"
zstat -A after +inode -- payload.tar.gz
[[ -n "$before" && "$before" == "$after" ]] && print -r -- GZ_PRESERVED
if (( $+commands[zopfli] )); then
    print -r -- payload > race
    targz race >/dev/null 2>&1
    print -r -- "RACE_RC=$?"
    [[ "$(<race.tar.gz)" == winner ]] && print -r -- RACE_PRESERVED
fi
scratch=(.targz.*(N))
(( ! ${#scratch} )) && print -r -- SCRATCH_REMOVED
EOF
    typeset bin='' name=''
    for name bin in zopfli "$zopflibin" pigz "$pigzbin" gzip "$nobin"; do
        work="$T_SCRATCH/targz-$name"
        mkdir -p "$work/payload"
        print -r -- hello > "$work/payload/file.txt"
        print -r -- original > "$work/payload.tar"
        out=$(zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$bin" "$targztools" "$work" 2>&1)
        assert_contains "$out" "using \`$name\`" "targz compresses with $name when it is the best available"
        assert_contains "$out" "payload.tar.gz (" "targz names the archive after the directory, trailing slash dropped ($name)"
        assert_contains "$out" "RC=0" "targz succeeds with $name"
        assert_contains "$out" GZ_WRITTEN "targz leaves the .tar.gz ($name)"
        assert_contains "$out" TAR_PRESERVED "targz preserves a pre-existing .tar ($name)"
        assert_contains "$out" COLLISION_RC=1 "targz rejects an existing .tar.gz ($name)"
        assert_contains "$out" GZ_PRESERVED "targz leaves the existing .tar.gz in place ($name)"
        assert_contains "$out" SCRATCH_REMOVED "targz removes its scratch directory ($name)"
        if [[ "$name" == zopfli ]]; then
            assert_contains "$out" RACE_RC=1 "targz fails if the destination appears during compression"
            assert_contains "$out" RACE_PRESERVED "targz preserves a destination created during compression"
        fi
    done
    assert_contains "$out" "Usage: targz <file-or-dir>" "targz with no argument prints its usage"
    assert_contains "$out" "USAGE_RC=1" "targz with no argument returns 1"
else
    t_skip "targz" "tar, rm, gzip, mktemp or ln not available"
fi

# ── tips ──────────────────────────────────────────────────────────────
# A tip is "keys: what they do"; a line without ": " prints whole.
typeset tipsconf="$T_SCRATCH/tipsconf" catbin="$T_SCRATCH/catbin"
mkdir -p "$tipsconf/data/tips"
print -rl -- 'git st: short status' 'git log --graph: log as a graph' > "$tipsconf/data/tips/git.txt"
print -r -- 'docker tip without keys' > "$tipsconf/data/tips/docker.txt"
if link_tools "$catbin" cat; then
    inner="$T_SCRATCH/tips.zsh"
    cat > "$inner" <<'EOF'
fpath=("$1/.zsh/functions" $fpath)
autoload -Uz tips
SHELL_CONFIG_DIR="$2"
path=("$3")
tips git
tips nope
print -r -- "UNKNOWN_RC=$?"
tips
EOF
    # Captured output is not a terminal, so it gets plain text.
    out=$(zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$tipsconf" "$catbin" 2>&1)
    assert_contains "$out" $'git st: short status\ngit log --graph: log as a graph' \
        "off a terminal, tips TOOL prints that tool's file"
    assert_contains "$out" "Available tools: docker, git" "tips for an unknown tool lists the known ones"
    assert_contains "$out" "UNKNOWN_RC=1" "tips for an unknown tool returns 1"
    case "${out##*$'\n'}" in
        ('[git] git st: short status'|'[git] git log --graph: log as a graph'|'[docker] docker tip without keys')
            t_pass "off a terminal, the daily tip is one tip, after its tool" ;;
        (*) t_fail "off a terminal, the daily tip is one tip, after its tool" "$out" ;;
    esac
else
    t_skip "tips" "cat not available"
fi

# On a terminal: the title in a rule that ends at column 80, or at the edge
# of a narrower terminal, over the tips with their keys in a column of their
# own, in the banner's colours.
inner="$T_SCRATCH/tips_tty.zsh"
cat > "$inner" <<'EOF'
fpath=("$1/.zsh/functions" $fpath)
autoload -Uz tips
SHELL_CONFIG_DIR="$2"
COLUMNS=120
tips git
COLUMNS=30
tips docker
COLUMNS=80
tips
EOF
if out=$(run_under_pty zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$tipsconf"); then
    typeset plain=$(print -r -- "$out" | sed $'s/\e\\[[0-9;]*m//g')
    assert_contains "$plain" $'  ─ ◆ TIPS / GIT '"${(l:63::─:)}"$'\n    git st           short status\n    git log --graph  log as a graph\n' \
        "tips TOOL: an 80-column rule on a wide terminal, the keys in a column"
    assert_contains "$plain" $'  ─ ◆ TIPS / DOCKER '"${(l:10::─:)}"$'\n    docker tip without keys\n' \
        "tips TOOL: the rule ends at a narrower terminal's edge; a tip without keys prints whole"
    assert_contains "$out" $'\e[1;38;2;212;109;254mgit st\e[0m' "keys are bold, in the banner's bright accent"
    assert_contains "$out" $'\e[38;2;176;159;254mshort status\e[0m' "descriptions are in the banner's text colour"
    typeset -a plines=("${(@f)plain}") want=(
        $'  ─ ◆ TIP / GIT '"${(l:64::─:)}"$'\n    git st  short status'
        $'  ─ ◆ TIP / GIT '"${(l:64::─:)}"$'\n    git log --graph  log as a graph'
        $'  ─ ◆ TIP / DOCKER '"${(l:61::─:)}"$'\n    docker tip without keys'
    )
    if (( ${want[(Ie)${(F)plines[-2,-1]}]} )); then
        t_pass "the daily tip is one tip, under a rule with its tool"
    else
        t_fail "the daily tip is one tip, under a rule with its tool" "$plain"
    fi
else
    t_skip "tips on a terminal" "no pseudo-terminal available (zsh/zpty)"
fi

# ── op-env: options and failures ──────────────────────────────────────
# test_regressions.zsh runs the main path. These are the other exits.
typeset openvbin="$T_SCRATCH/openvbin" emptybin="$T_SCRATCH/emptybin"
mkdir -p "$emptybin"
make_stub "$openvbin" op 'printf "op %s\n" "$*" >> "$OP_LOG"
case "$1" in
    item)
        [ -n "$OP_LOCKED" ] && exit 1
        printf "FOO=from_op\n"
        ;;
    run)
        shift
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
esac'
inner="$T_SCRATCH/openv.zsh"
cat > "$inner" <<'EOF'
fpath=("$1/.zsh/functions" $fpath)
autoload -Uz op-env
path=("$2" $path)
case "$3" in
    help)      op-env --help ;;
    unknown)   op-env -x some-item -- true ;;
    nocommand) op-env some-item ;;
    account)   op-env some-item --account acme -- /bin/sh -c 'printf "GOT=%s\n" "$FOO"' ;;
    bare)      op-env some-item /bin/sh -c 'printf "GOT=%s\n" "$FOO"' ;;
    noop)      path=("$4"); op-env some-item -- true ;;
    locked)    op-env some-item -- true ;;
esac
print -r -- "RC=$?"
EOF
typeset oplog="$T_SCRATCH/openv.log" mode='' locked=''
for mode in help unknown nocommand account bare noop locked; do
    : > "$oplog"
    locked=''
    [[ "$mode" == locked ]] && locked=1
    out=$(OP_LOG="$oplog" OP_LOCKED="$locked" \
        zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$openvbin" "$mode" "$emptybin" 2>&1)
    case "$mode" in
        help)
            assert_contains "$out" "Usage: op-env <item-name-or-id>" "op-env --help prints the usage"
            assert_contains "$out" "RC=0" "op-env --help succeeds" ;;
        unknown)
            assert_contains "$out" "op-env: unknown option: -x" "op-env names an unknown option"
            assert_contains "$out" "RC=2" "an unknown option returns 2" ;;
        nocommand)
            assert_contains "$out" "op-env: usage:" "op-env without a command prints the usage"
            assert_contains "$out" "RC=2" "op-env without a command returns 2" ;;
        account)
            assert_contains "$out" "GOT=from_op" "op-env --account still runs the command with the item's vars"
            assert_contains "$(<"$oplog")" "item get some-item --account acme" "--account picks the account the item is read from"
            assert_contains "$(<"$oplog")" "run --account acme" "--account picks the account op run resolves references in" ;;
        bare)
            assert_contains "$out" "GOT=from_op" "the first word after the item starts the command, even without --"
            assert_contains "$out" "RC=0" "op-env without -- succeeds" ;;
        noop)
            assert_contains "$out" "1Password CLI (op) not installed" "op-env says when op is missing"
            assert_contains "$out" "RC=1" "a missing op returns 1" ;;
        locked)
            assert_contains "$out" "cannot read 1Password item 'some-item' from account 'famfam.1password.com'" \
                "op-env names the item and account it could not read"
            assert_contains "$out" "RC=1" "an unreadable item returns 1"
            assert_not_contains "$(<"$oplog")" "op run" "an unreadable item runs nothing" ;;
    esac
done

# ── gam: fetching the credentials from 1Password ──────────────────────
# test_regressions.zsh covers the no-op case. Here op answers: the two
# documents land in ~/.gam as 0600 files, once, and then the real gam runs.
typeset gambin="$T_SCRATCH/gambin"
make_stub "$gambin" op 'printf "op %s\n" "$*" >> "$OP_LOG"
[ -n "$OP_FAIL" ] && exit 1
printf "secret for %s\n" "$3"'
make_stub "$gambin" gam 'printf "real gam %s\n" "$*"'
inner="$T_SCRATCH/gam.zsh"
cat > "$inner" <<'EOF'
fpath=("$1/.zsh/functions" $fpath)
autoload -Uz gam
path=("$2" $path)
gam info domain
print -r -- "GAM_RC=$?"
zmodload -F zsh/stat b:zstat
typeset f='' mode=''
for f in client_secrets.json oauth2service.json; do
    [[ -f "$HOME/.gam/$f" ]] || continue
    zstat -A mode +mode "$HOME/.gam/$f"
    printf 'MODE[%s]=%o\n' "$f" $(( mode[1] & 8#777 ))
    print -r -- "CONTENT[$f]=$(<"$HOME/.gam/$f")"
done
leftover=("$HOME/.gam"/.pull.*(N))
print -r -- "LEFTOVER=${#leftover}"
gam info again
EOF
typeset gamhome="$T_SCRATCH/gamhome-ok" gamlog="$T_SCRATCH/gam-op.log"
mkdir -p "$gamhome"
: > "$gamlog"
out=$(HOME="$gamhome" OP_LOG="$gamlog" zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$gambin" 2>&1)
assert_contains "$out" "real gam info domain" "gam runs the real binary once the credentials are in place"
assert_contains "$out" "GAM_RC=0" "gam succeeds after fetching"
assert_contains "$out" "MODE[client_secrets.json]=600" "client_secrets.json is private (0600)"
assert_contains "$out" "MODE[oauth2service.json]=600" "oauth2service.json is private (0600)"
assert_contains "$out" "CONTENT[client_secrets.json]=secret for GAM client_secrets" "client_secrets.json holds the fetched document"
assert_contains "$out" "CONTENT[oauth2service.json]=secret for GAM oauth2service" "oauth2service.json holds the fetched document"
assert_contains "$out" "LEFTOVER=0" "no temporary file is left behind"
assert_contains "$out" "real gam info again" "a second call runs gam directly"
assert_eq "${#${(f)$(<"$gamlog")}}" 2 "the documents are fetched once, not on every call"
assert_contains "$(<"$gamlog")" "--account famfam.1password.com --vault Private" "gam reads from the configured account and vault"

gamhome="$T_SCRATCH/gamhome-locked"
mkdir -p "$gamhome"
: > "$gamlog"
out=$(HOME="$gamhome" OP_LOG="$gamlog" OP_FAIL=1 zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$gambin" 2>&1)
assert_contains "$out" "gam: could not fetch 'GAM client_secrets' from 1Password (famfam.1password.com/Private)" \
    "a failed fetch names the document and where it was looked for"
assert_contains "$out" "GAM_RC=1" "a failed fetch returns 1"
assert_not_contains "$out" "real gam" "a failed fetch never runs gam"
assert_not_contains "$out" "MODE[" "a failed fetch leaves no credential file"
assert_contains "$out" "LEFTOVER=0" "a failed fetch leaves no temporary file"

# ── claude inside tmux ────────────────────────────────────────────────
# test_regressions.zsh runs the wrapper outside tmux. Inside, it pins the
# window title to the project for the session and pops it afterwards.
typeset claudebin="$T_SCRATCH/claudebin"
make_stub "$claudebin" claude 'printf "claude ran %s\n" "$*"'
work="$T_SCRATCH/projectx"
mkdir -p "$work"
inner="$T_SCRATCH/claude_tmux.zsh"
cat > "$inner" <<'EOF'
fpath=("$1/.zsh/functions" $fpath)
autoload -Uz claude
path=("$2" $path)
tmux() {
    [[ "$1" == display-message ]] || return 0
    [[ "$3" == '#{pane_id}' ]] && print -r -- '%7' || print -r -- '@3'
}
_tmux_title_push() { print -r -- "PUSH $1 $2 $3"; }
_tmux_title_pop() { print -r -- "POP $1 $2"; }
TMUX=/tmp/fake,1,0
cd "$3"
claude --probe
print -r -- "RC=$?"
EOF
out=$(zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$claudebin" "$work" 2>&1)
assert_eq "$out" $'PUSH %7 @3 ✨ projectx\nclaude ran --probe\nPOP %7 @3\nRC=0' \
    "in tmux, claude pins the window title to the project, runs, then pops it once"

# ── atuin-fzf-history: the ctrl-y clipboard command ───────────────────
# fzf runs ctrl-y in a non-interactive shell, where the Linux pbcopy alias
# does not exist, so the widget picks a real binary. fzf and zle are
# stand-ins; only which copier lands in the binding is checked.
typeset bindlog="$T_SCRATCH/fzf-bind" copier='' dir=''
inner="$T_SCRATCH/widget_copy.zsh"
cat > "$inner" <<'EOF'
source "$1/.zsh/functions/atuin-fzf-history"
bind_log="$3"
path=("$2")
zle() { : }
fzf() {
    local a
    for a; do [[ "$a" == ctrl-y:* ]] && print -r -- "$a" > "$bind_log"; done
    return 130
}
atuin-fzf-history
EOF
for copier expected in \
    pbcopy  'printf %s {} | pbcopy' \
    wl-copy 'printf %s {} | wl-copy' \
    xclip   'printf %s {} | xclip -selection clipboard -in' \
    xsel    'printf %s {} | xsel --clipboard --input' \
    none    'printf %s {} | cat > /dev/null'
do
    dir="$T_SCRATCH/copier-$copier"
    mkdir -p "$dir"
    [[ "$copier" != none ]] && make_stub "$dir" "$copier"
    rm -f "$bindlog"
    zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$dir" "$bindlog" >/dev/null 2>&1
    assert_eq "$(<"$bindlog" 2>/dev/null)" "ctrl-y:execute-silent($expected)+abort" \
        "ctrl-y copies with ${${copier:#none}:-nothing (no clipboard tool)}"
done
# With several Linux tools installed, Wayland's comes first.
dir="$T_SCRATCH/copier-all"
for copier in wl-copy xclip xsel; do make_stub "$dir" "$copier"; done
rm -f "$bindlog"
zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$dir" "$bindlog" >/dev/null 2>&1
assert_eq "$(<"$bindlog" 2>/dev/null)" "ctrl-y:execute-silent(printf %s {} | wl-copy)+abort" \
    "wl-copy wins over xclip and xsel"

t_finish
