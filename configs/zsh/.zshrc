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

# Module loading helper. Note: the local is named _path, NOT module_path —
# `module_path` is a zsh special array aliased to $MODULE_PATH, and shadowing
# it as a scalar breaks zmodload auto-loading inside the sourced module
# (e.g. fzf --zsh's `[[ =~ ]]` triggers an auto-load of zsh/regex).
load_module() {
    local module_type=$1
    local module_name=$2
    local _path

    case "$module_type" in
        "lib")      _path="$SHELL_LIB_DIR/${module_name}.zsh" ;;
        "function") _path="$SHELL_FUNCTIONS_DIR/${module_name}.zsh" ;;
        *)          return 1 ;;
    esac

    if [[ -f "$_path" ]]; then
        source "$_path"
        return 0
    fi
    return 1
}

# Load core library modules in specific order.
# Function-defining modules (history, completion, aliases, ls, keybindings,
# integrations) must load before shell.zsh, which orchestrates them via
# init_shell after .zshrc finishes sourcing.
core_modules=(
    "platform_detection" # Must be first for platform detection
    "executables"        # Executable setup
    "clipboard"          # clipcopy/clippaste with detect-once stubs
    "environment"        # Environment setup
    "history"            # History configuration + hgrep/recent/remember/recalls
    "completion"         # Completion zstyles and compdefs
    "aliases"            # Alias definitions + git_cleanup/docker_cleanup
    "ls"                 # dircolors/ls/eza aliases
    "keybindings"        # setup_readline (vi mode, fzf, atuin, tmux-sessionizer)
    "integrations"       # zoxide + atuin-fzf-history widget
    "shell"              # Shell orchestration (setup_shell_options, init_shell)
    "prompt"             # Prompt setup (plx init + OSC 7 + startup banner)
    "tmux_title"         # Helpers for pinning tmux titles around wrapped commands
    "ssh"                # SSH configuration
    "tmux_emoji_titles"  # Automatic emoji titles for tmux windows
    "utils"              # Utility functions
)

for module in "${core_modules[@]}"; do
    load_module "lib" "$module"
done

# Lazy load function modules — on first call, replace the stub with the
# real implementation from the module, then dispatch to it.
_lazy_module_fn() {
    local stub="$1" module="$2" real="$3"
    eval "$stub() { unfunction $stub; load_module function $module; $real \"\$@\"; }"
}

_lazy_module_fn tips          tips          tips
_lazy_module_fn system_health system_health display_system_health

# Initialize core components. fzf --zsh is sourced inside keybindings.zsh
# at module-load so setup_readline's ^R → atuin-fzf-history binding lands
# after fzf's own ^R binding.
setup_environment
init_shell
init_prompt
setup_integrations

# Display system status on first shell (login or first interactive, not subshells)
if [[ -o login || -z "$INFLUX_SHOWN" ]] && command -v gum &>/dev/null; then
    export INFLUX_SHOWN=1
    notify_shell_status
    tips
fi

# Final cleanup
unset core_modules

# Disable correction for specific commands
CORRECT_IGNORE='.*|claude'

# Load claude wrapper function
if [[ -f "$SHELL_FUNCTIONS_DIR/claude_wrapper.zsh" ]]; then
    source "$SHELL_FUNCTIONS_DIR/claude_wrapper.zsh"
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
