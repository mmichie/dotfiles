#!/usr/bin/env zsh
# Startup-module branches that depend on the machine: the OS and CPU
# detected, whether nvim, eza or GNU ls are installed, and which clipboard
# tool the session has. A test run only ever takes the branches of the
# machine it runs on, so each probe sets the condition itself: OSTYPE and
# CPUTYPE are assigned before detection, PATH is narrowed to stubs, and the
# display variables are set or cleared.
#
# Not covered here: FreeBSD, an unknown OS or CPU, and WSL's clip.exe. They
# exist for machines this config is not used on.

source "${0:A:h}/lib.zsh"

typeset inner='' out='' dir='' expected=''

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

# ── 00-platform: OS, architecture, capabilities ───────────────────────
inner="$T_SCRATCH/platform.zsh"
cat > "$inner" <<'EOF'
source "$1/.zsh/lib/00-platform.zsh"
OSTYPE=linux-gnu CPUTYPE=x86_64
detect_platform
print -r -- "LINUX_X86=$SYSTEM_OS_TYPE/$SYSTEM_ARCH linux=$(is_linux && print y) osx=$(is_osx && print y) arm=$(is_arm && print y)"
OSTYPE=darwin24.0 CPUTYPE=arm64
detect_platform
print -r -- "DARWIN_ARM=$SYSTEM_OS_TYPE/$SYSTEM_ARCH linux=$(is_linux && print y) osx=$(is_osx && print y) arm=$(is_arm && print y)"
OSTYPE=linux-gnu CPUTYPE=aarch64
detect_platform
print -r -- "LINUX_AARCH64=$SYSTEM_OS_TYPE/$SYSTEM_ARCH"
SYSTEM_CAPABILITIES=(nix docker)
has_capability docker; print -r -- "HAS_DOCKER=$?"
has_capability homebrew; print -r -- "HAS_HOMEBREW=$?"
EOF
out=$(zsh --no-globalrcs -f "$inner" "$ZSH_CONF" 2>&1)
assert_contains "$out" "LINUX_X86=LINUX/x86_64 linux=y osx= arm=" "Linux on x86_64 is detected as such"
assert_contains "$out" "DARWIN_ARM=OSX/arm64 linux= osx=y arm=y" "macOS on Apple Silicon is detected as such"
assert_contains "$out" "LINUX_AARCH64=LINUX/arm64" "aarch64 is reported as arm64, the same as Apple Silicon"
assert_contains "$out" "HAS_DOCKER=0" "has_capability finds a listed capability"
assert_contains "$out" "HAS_HOMEBREW=1" "has_capability fails for an unlisted one"

# ── 10-environment: the editor ────────────────────────────────────────
# nvim when installed (vim and vi alias to it), else vim -f. setup_environment
# runs when the module is sourced and needs only mkdir from PATH.
typeset envtools="$T_SCRATCH/envtools" envnvim="$T_SCRATCH/envnvim"
if link_tools "$envtools" mkdir && link_tools "$envnvim" mkdir; then
    make_stub "$envnvim" nvim
    inner="$T_SCRATCH/editor.zsh"
    cat > "$inner" <<'EOF'
source "$1/.zsh/lib/00-platform.zsh"
# Keep setup_environment's directories inside the scratch HOME.
unset XDG_CONFIG_HOME XDG_CACHE_HOME XDG_DATA_HOME XDG_STATE_HOME
path=("$2")
source "$1/.zsh/lib/10-environment.zsh"
print -r -- "EDITOR=$EDITOR|VISUAL=$VISUAL|P4EDITOR=$P4EDITOR|vim=${aliases[vim]-none}|vi=${aliases[vi]-none}"
EOF
    typeset edhome="$T_SCRATCH/edhome"
    mkdir -p "$edhome"
    out=$(HOME="$edhome" zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$envtools" 2>&1)
    assert_contains "$out" "EDITOR=vim -f|VISUAL=vim -f|P4EDITOR=vim -f|vim=none|vi=none" \
        "without nvim the editor is vim -f, and vim is not aliased"
    out=$(HOME="$edhome" zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$envnvim" 2>&1)
    assert_contains "$out" "EDITOR=nvim|VISUAL=nvim|P4EDITOR=nvim|vim=nvim|vi=nvim" \
        "with nvim installed it is the editor, and vim and vi run it"
else
    t_skip "editor selection" "mkdir not available"
fi

# ── 35-ls: aliases without eza ────────────────────────────────────────
# Without eza, ls is GNU ls (gls) on macOS when Homebrew coreutils is there,
# BSD ls with CLICOLOR otherwise, and GNU ls --color on Linux.
typeset lsgls="$T_SCRATCH/ls-gls" lsnone="$T_SCRATCH/ls-none" lseza="$T_SCRATCH/ls-eza"
make_stub "$lsgls" gls
mkdir -p "$lsnone"
make_stub "$lseza" eza
inner="$T_SCRATCH/ls_aliases.zsh"
cat > "$inner" <<'EOF'
source "$1/.zsh/lib/00-platform.zsh"
path=("$2")
OSTYPE="$3"
detect_platform
unset CLICOLOR LSCOLORS
source "$1/.zsh/lib/35-ls.zsh"
print -r -- "LS=${aliases[ls]}|LL=${aliases[ll]}|LA=${aliases[la]}|L=${aliases[l]}"
print -r -- "CLICOLOR=${CLICOLOR-unset}|LSCOLORS=${LSCOLORS-unset}"
EOF
out=$(zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$lsgls" darwin24.0 2>&1)
assert_contains "$out" "LS=gls --color=auto -F|LL=ls -lh|LA=ls -A|L=ls -CF" "macOS without eza uses gls when it is installed"
assert_contains "$out" "CLICOLOR=unset" "with gls, BSD ls colour variables are left alone"
out=$(zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$lsnone" darwin24.0 2>&1)
assert_contains "$out" "LS=ls -F|LL=ls -lh|LA=ls -A|L=ls -CF" "macOS without eza or gls uses BSD ls"
assert_contains "$out" "CLICOLOR=1|LSCOLORS=ExGxFxdaCxDaDahbadacec" "BSD ls gets its colours from CLICOLOR and LSCOLORS"
out=$(zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$lsnone" linux-gnu 2>&1)
assert_contains "$out" "LS=ls --color=auto -F|LL=ls -lh|LA=ls -A|L=ls -CF" "Linux without eza uses GNU ls with colour"
out=$(zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$lseza" linux-gnu 2>&1)
assert_contains "$out" "LS=_ls_command|" "with eza installed, ls goes through the translating dispatcher"

# ── 35-ls: the ls dispatcher ──────────────────────────────────────────
# What `ls` runs: eza for flag clusters the translator understands, then GNU
# ls (gls) for the rest, then the platform's own ls. The ls stub reports
# CLICOLOR because BSD ls only colours with it set.
typeset lsfull="$T_SCRATCH/lsdispatch-full" lsplain="$T_SCRATCH/lsdispatch-plain"
make_stub "$lsfull" eza 'printf "eza %s\n" "$*"'
make_stub "$lsfull" gls 'printf "gls %s\n" "$*"'
make_stub "$lsplain" ls 'printf "ls CLICOLOR=%s %s\n" "$CLICOLOR" "$*"'
inner="$T_SCRATCH/ls_dispatch.zsh"
cat > "$inner" <<'EOF'
source "$1/.zsh/lib/00-platform.zsh"
source "$1/.zsh/lib/35-ls.zsh"
path=("$2")
OSTYPE="$3"
unset CLICOLOR
_ls_command "${@[4,-1]}"
EOF
out=$(zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$lsfull" darwin24.0 -la somedir 2>&1)
assert_eq "$out" "eza --group-directories-first --icons --long --all -- somedir" \
    "ls -la goes to eza, translated, with the house options"
out=$(zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$lsfull" darwin24.0 -lG 2>&1)
assert_eq "$out" "gls --color=auto -lG" "a cluster eza cannot take goes to GNU ls untranslated"
out=$(zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$lsplain" darwin24.0 -lG 2>&1)
assert_eq "$out" "ls CLICOLOR=1 -lG" "without gls, macOS falls back to BSD ls with colour switched on"
out=$(zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$lsplain" linux-gnu -lG 2>&1)
assert_eq "$out" "ls CLICOLOR= --color=auto -lG" "without gls, Linux falls back to its own ls with --color"

# ── 40-clipboard: backends ────────────────────────────────────────────
# clipcopy and clippaste start as stubs that detect the backend on first
# use. Each case puts one session's tools on PATH (plus cat, which the copy
# bodies read through), copies a payload and pastes it back. The copy stubs
# store stdin in $CLIP_STORE; wl-copy and xclip are backgrounded by the
# copy body, so their store is polled for.
typeset clipcat="$T_SCRATCH/clipcat"
if link_tools "$clipcat" cat; then
    typeset copy_body='printf "%s %s\n" "${0##*/}" "$*" >> "$CLIP_LOG"
while IFS= read -r line || [ -n "$line" ]; do printf "%s" "$line"; done > "$CLIP_STORE"'
    typeset paste_body='printf "%s %s\n" "${0##*/}" "$*" >> "$CLIP_LOG"
while IFS= read -r line || [ -n "$line" ]; do printf "%s" "$line"; done < "$CLIP_STORE"'
    # One stub serving both directions, told apart by its arguments.
    typeset both_body='case "$*" in
    *--input*|*-in*|load-buffer*) mode=copy ;;
    *) mode=paste ;;
esac
printf "%s %s\n" "${0##*/}" "$*" >> "$CLIP_LOG"
if [ "$mode" = copy ]; then
    while IFS= read -r line || [ -n "$line" ]; do printf "%s" "$line"; done > "$CLIP_STORE"
else
    while IFS= read -r line || [ -n "$line" ]; do printf "%s" "$line"; done < "$CLIP_STORE"
fi'

    inner="$T_SCRATCH/clipboard.zsh"
    cat > "$inner" <<'EOF'
OSTYPE="$3"
unset WAYLAND_DISPLAY DISPLAY TMUX
[[ -n "$4" ]] && export "${(@s: :)4}"
path=("$2")
source "$1/.zsh/lib/40-clipboard.zsh"
print -r -- "PBCOPY_ALIAS=${aliases[pbcopy]-none}"
print -rn -- clip-payload | clipcopy
copy_rc=$?
print -r -- "COPY_RC=$copy_rc"
# zselect -t waits in hundredths of a second without needing sleep on PATH.
zmodload zsh/zselect
if (( copy_rc == 0 )); then
    repeat 50; do [[ -s "$CLIP_STORE" ]] && break; zselect -t 10; done
fi
pasted="$(clippaste)"
print -r -- "PASTE_RC=$? PASTED=$pasted"
EOF
    # run_clip <case> <OSTYPE> <env assignments> <tool...>
    typeset clipstore='' cliplog=''
    run_clip() {
        local name="$1" ostype="$2" assignments="$3" t
        shift 3
        dir="$T_SCRATCH/clip-$name"
        mkdir -p "$dir"
        ln -sf "$clipcat/cat" "$dir/cat"
        for t in "$@"; do
            case "$t" in
                wl-copy|pbcopy) make_stub "$dir" "$t" "$copy_body" ;;
                wl-paste|pbpaste) make_stub "$dir" "$t" "$paste_body" ;;
                *) make_stub "$dir" "$t" "$both_body" ;;
            esac
        done
        clipstore="$T_SCRATCH/clip-$name.store" cliplog="$T_SCRATCH/clip-$name.log"
        rm -f "$clipstore" "$cliplog"
        out=$(CLIP_STORE="$clipstore" CLIP_LOG="$cliplog" \
            zsh --no-globalrcs -f "$inner" "$ZSH_CONF" "$dir" "$ostype" "$assignments" 2>&1)
    }

    run_clip wayland linux-gnu 'WAYLAND_DISPLAY=wayland-0' wl-copy wl-paste
    assert_contains "$out" "PASTED=clip-payload" "Wayland: what clipcopy stores, clippaste returns"
    assert_eq "$(<"$cliplog")" $'wl-copy \nwl-paste --no-newline' "Wayland uses wl-copy and wl-paste"
    assert_contains "$out" "PBCOPY_ALIAS=clipcopy" "off macOS, pbcopy is an alias for clipcopy"

    run_clip xsel linux-gnu 'DISPLAY=:0' xsel
    assert_contains "$out" "PASTED=clip-payload" "X11 with xsel: the payload round-trips"
    assert_eq "$(<"$cliplog")" $'xsel --clipboard --input\nxsel --clipboard --output' "X11 with xsel uses the CLIPBOARD selection"

    run_clip xclip linux-gnu 'DISPLAY=:0' xclip
    assert_contains "$out" "PASTED=clip-payload" "X11 with xclip: the payload round-trips"
    assert_eq "$(<"$cliplog")" $'xclip -selection clipboard -in\nxclip -out -selection clipboard' "X11 with xclip uses the CLIPBOARD selection"

    run_clip tmux linux-gnu 'TMUX=/tmp/fake,1,0' tmux
    assert_contains "$out" "PASTED=clip-payload" "inside tmux with no display: the payload round-trips through a tmux buffer"
    assert_eq "$(<"$cliplog")" $'tmux load-buffer -w -\ntmux save-buffer -' "tmux copies with load-buffer -w, so the terminal gets it too"

    run_clip none linux-gnu ''
    assert_contains "$out" "clipcopy: no clipboard backend found on linux-gnu" "with no backend, clipcopy says so"
    assert_contains "$out" "COPY_RC=1" "with no backend, clipcopy fails"
    assert_contains "$out" "clippaste: no clipboard backend found on linux-gnu" "with no backend, clippaste says so"
    assert_contains "$out" "PASTE_RC=1" "with no backend, clippaste fails"

    # Precedence: Wayland over X11, and xsel over xclip.
    run_clip waylandfirst linux-gnu 'WAYLAND_DISPLAY=wayland-0 DISPLAY=:0' wl-copy wl-paste xsel xclip
    assert_eq "${${(f)$(<"$cliplog")}[1]}" "wl-copy " "with both Wayland and X11, wl-copy wins"
    run_clip xselfirst linux-gnu 'DISPLAY=:0' xsel xclip
    assert_eq "${${(f)$(<"$cliplog")}[1]}" "xsel --clipboard --input" "with both installed, xsel wins over xclip"

    run_clip macos darwin24.0 '' pbcopy pbpaste
    assert_contains "$out" "PASTED=clip-payload" "macOS: the payload round-trips through pbcopy and pbpaste"
    assert_contains "$out" "PBCOPY_ALIAS=none" "on macOS, pbcopy stays the real binary"
else
    t_skip "clipboard backends" "cat not available"
fi

t_finish
