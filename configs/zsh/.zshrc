#!/bin/zsh

# First thing: measure shell startup time if PROFILE_STARTUP is set.
# Set PROFILE_STARTUP_RESET=1 alongside to force a cold rebuild of the
# compinit dump (otherwise PROFILE_STARTUP measures the warm fast path,
# which is what you usually want).
if [[ -n "$PROFILE_STARTUP" ]]; then
  if [[ -n "$PROFILE_STARTUP_RESET" ]]; then
    rm -f "$HOME/.zcompdump" "$HOME/.cache/zsh/.zcompdump"{,.zwc,.fpath} 2>/dev/null
  fi
  zmodload zsh/zprof
fi

# Early exit for non-interactive shells
[[ $- != *i* ]] && return

# Initialize essential variables
declare -gx SHELL_CONFIG_DIR="$HOME/.zsh"
declare -gx SHELL_LIB_DIR="$SHELL_CONFIG_DIR/lib"
declare -gx SHELL_FUNCTIONS_DIR="$SHELL_CONFIG_DIR/functions"
declare -gx SHELL_CACHE_DIR="$HOME/.cache/zsh"

# Set up fpath for zsh functions. (N-/) qualifier silently drops paths
# that don't exist or aren't directories, so no existence loop needed.
# -U keeps it duplicate-free so re-sourcing this file is idempotent (a
# changed fingerprint would otherwise force a compinit rebuild per reload).
typeset -gU fpath
fpath=(
    /usr/share/zsh/site-functions(N-/)
    /usr/local/share/zsh/site-functions(N-/)
    /opt/homebrew/share/zsh/site-functions(N-/)
    /usr/share/zsh/functions/Completion(N-/)
    /usr/share/zsh/functions/Completion/Unix(N-/)
    /usr/share/zsh/functions/Completion/Linux(N-/)
    /usr/share/zsh/vendor-functions(N-/)
    "$SHELL_FUNCTIONS_DIR"(N-/)
    $fpath
)

[[ -d "$SHELL_CACHE_DIR" ]] || mkdir -p "$SHELL_CACHE_DIR"

# Load completion system. compinit -C is fast but doesn't notice fpath
# changes on its own; fingerprint fpath into a sidecar file and rebuild only
# when it shifts. The sidecar (not a line appended to the dump) keeps the
# dump pristine for zcompile and costs a fork-free $(<...) instead of a grep.
ZSH_COMPDUMP="$SHELL_CACHE_DIR/.zcompdump"
autoload -Uz compinit
_fpath_fingerprint="${(j::)fpath}"
if [[ -f "$ZSH_COMPDUMP" && -r "$ZSH_COMPDUMP.fpath" ]] \
    && [[ "$(<"$ZSH_COMPDUMP.fpath")" == "$_fpath_fingerprint" ]]; then
    compinit -C -d "$ZSH_COMPDUMP"
    # One-time backfill after deploys: compile the dump if no wordcode yet.
    [[ -f "$ZSH_COMPDUMP.zwc" ]] || zcompile "$ZSH_COMPDUMP" 2>/dev/null
else
    command rm -f "$ZSH_COMPDUMP" "$ZSH_COMPDUMP.zwc"
    compinit -i -d "$ZSH_COMPDUMP"
    zcompile "$ZSH_COMPDUMP" 2>/dev/null
    print -r -- "$_fpath_fingerprint" >| "$ZSH_COMPDUMP.fpath"
fi
unset _fpath_fingerprint

# No re-source guard: `source ~/.zshrc` is the documented reload path, so
# everything below is written to be idempotent — unique fpath/path, deduped
# hook registration, mtime-gated cache work, add-zsh-hook semantics.

# NOTE: do NOT manually source /etc/zshrc here. zsh already sources it for
# interactive shells (GLOBAL_RCS), and nix-darwin's guard makes a re-source
# a no-op only in that case — in a NO_GLOBAL_RCS shell the manual source
# re-runs the whole file, including a bare `compinit` that prompts (and
# aborts headless), clobbering the curated compinit above.

# Load library modules in numeric-prefix order. Each module is self-contained:
# it defines its functions, sets its options, and runs its own setup at
# source time. Filename prefix (00-, 05-, 10-, ...) encodes the load order
# — no orchestrator function or module list needed.
for module in "$SHELL_LIB_DIR"/[0-9]*.zsh; do
    source "$module"
done
unset module

# Autoload every file under $SHELL_FUNCTIONS_DIR. Each becomes a function
# defined on first call: zsh sources the file from $fpath, the definition
# inside is registered, and the function is dispatched with the original
# args. Skip *.zsh files (sourced explicitly elsewhere, if any).
for _fn in "$SHELL_FUNCTIONS_DIR"/*(N); do
    [[ "$_fn" == *.zsh ]] && continue
    autoload -Uz "${_fn:t}"
done
unset _fn

# Disable correction for dotfile-named commands and `claude` (zsh alternation
# requires the parens — `.*|claude` without grouping is a literal string match
# that never fires, so correction effectively ran on every command).
CORRECT_IGNORE='(.*|claude)'

# Banner + tip, at most once per BANNER_INTERVAL seconds (default hourly)
# across all shells, tracked by a stamp file. The old `-o login` gate fired
# on every macOS terminal tab and tmux pane (~90ms each); the stamp makes it
# genuinely "first shell in a while". INFLUX_SHOWN=1 suppresses entirely
# (tests, scripted shells).
if [[ -z "$INFLUX_SHOWN" ]] && command -v gum &>/dev/null; then
    _banner_recent=("$SHELL_CACHE_DIR/banner-stamp"(N.ms-${BANNER_INTERVAL:-3600}))
    if (( ${#_banner_recent} == 0 )); then
        export INFLUX_SHOWN=1
        # Stamp before displaying: rate-limits the attempt, so a banner
        # renderer dying mid-draw cannot re-trigger every shell.
        : >| "$SHELL_CACHE_DIR/banner-stamp"
        notify_shell_status
        tips
    fi
    unset _banner_recent
fi

# Source local config (not in dotfiles repo, for secrets/machine-specific settings)
# Login-only setup (e.g. macOS path_helper re-application) lives in .zprofile.
[ -f ~/.zshrc.local ] && source ~/.zshrc.local
[ -f ~/.zshrc-work-local ] && source ~/.zshrc-work-local

# Display profiling results if PROFILE_STARTUP is set (must be last to capture everything)
if [[ -n "$PROFILE_STARTUP" ]]; then
  zprof
fi
