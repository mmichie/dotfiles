#!/bin/zsh

# First thing: measure shell startup time if PROFILE_STARTUP is set
if [[ -n "$PROFILE_STARTUP" ]]; then
  # Reset zsh cache (check both legacy $HOME and the new cache-dir location)
  rm -f "$HOME/.zcompdump" "$HOME/.cache/zsh/.zcompdump" 2>/dev/null
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

mkdir -p "$SHELL_CACHE_DIR"

# Load completion system. compinit -C is fast but doesn't notice fpath
# changes on its own; fingerprint fpath into the dump and rebuild only
# when it shifts.
ZSH_COMPDUMP="$SHELL_CACHE_DIR/.zcompdump"
autoload -Uz compinit
_fpath_fingerprint="#fpath: ${(j::)fpath}"
if command grep -q -Fx "$_fpath_fingerprint" "$ZSH_COMPDUMP" 2>/dev/null; then
    compinit -C -d "$ZSH_COMPDUMP"
else
    command rm -f "$ZSH_COMPDUMP"
    compinit -i -d "$ZSH_COMPDUMP"
    print -- "$_fpath_fingerprint" >> "$ZSH_COMPDUMP"
fi
unset _fpath_fingerprint

# Prevent multiple sourcing
if [[ -n "$ZSH_INITIALIZED" ]]; then
    return 0
fi
ZSH_INITIALIZED=1

# Source global definitions if available
[[ -f /etc/zshrc ]] && source /etc/zshrc

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

# Disable correction for specific commands
CORRECT_IGNORE='.*|claude'

# Display system status on first interactive shell
if [[ -o login || -z "$INFLUX_SHOWN" ]] && command -v gum &>/dev/null; then
    export INFLUX_SHOWN=1
    notify_shell_status
    tips
fi

# macOS path_helper fix: Login shells may have PATH reset by /etc/zprofile
# Re-run setup_path to ensure our paths are in the correct order
if is_osx && [[ -o login ]]; then
    setup_path
fi

# Source local config (not in dotfiles repo, for secrets/machine-specific settings)
[ -f ~/.zshrc.local ] && source ~/.zshrc.local

# Display profiling results if PROFILE_STARTUP is set (must be last to capture everything)
if [[ -n "$PROFILE_STARTUP" ]]; then
  zprof
fi
