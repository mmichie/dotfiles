#!/bin/zsh

# First thing: measure shell startup time if PROFILE_STARTUP is set
if [[ -n "$PROFILE_STARTUP" ]]; then
  # Reset zsh cache
  [[ -e "$HOME/.zcompdump" ]] && rm -f "$HOME/.zcompdump"
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

# Load completion system with caching and optimization
autoload -Uz compinit
# Skip security check for faster startup
compinit -C

mkdir -p "$SHELL_CACHE_DIR"

# Prevent multiple sourcing
if [[ -n "$ZSH_INITIALIZED" ]]; then
    return 0
fi
ZSH_INITIALIZED=1

# Source global definitions if available
[[ -f /etc/zshrc ]] && source /etc/zshrc

# Module loading helper function
load_module() {
    local module_type=$1
    local module_name=$2
    local module_path

    case "$module_type" in
        "lib")      module_path="$SHELL_LIB_DIR/${module_name}.zsh" ;;
        "function") module_path="$SHELL_FUNCTIONS_DIR/${module_name}.zsh" ;;
        *)          return 1 ;;
    esac

    if [[ -f "$module_path" ]]; then
        source "$module_path"
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

# Load utility functions
load_module "function" "utils"

# Initialize core components
setup_environment
init_shell
init_prompt

# FZF key bindings and completion (fzf from nix)
if command -v fzf &>/dev/null; then
    source <(fzf --zsh)
fi

# Load work profile if it exists
if [[ -f "$HOME/.bash_work_profile" ]]; then
    source "$HOME/.bash_work_profile"
fi

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

# Atuin shell history (disable keybindings — fzf handles Ctrl-R)
if command -v atuin &>/dev/null; then
    eval "$(atuin init zsh --disable-up-arrow --disable-ctrl-r)"
fi

# macOS path_helper fix: Login shells may have PATH reset by /etc/zprofile
# Re-run setup_path to ensure our paths are in the correct order
if is_osx && [[ -o login ]]; then
    setup_path
fi

# Direnv hook (per-directory environment variables)
if command -v direnv &>/dev/null; then
    eval "$(direnv hook zsh)"
fi

# Vivid ls colors
if command -v vivid &>/dev/null; then
    export LS_COLORS="$(vivid generate tokyonight-night)"
fi

# Source local config (not in dotfiles repo, for secrets/machine-specific settings)
[ -f ~/.zshrc.local ] && source ~/.zshrc.local

# Display profiling results if PROFILE_STARTUP is set (must be last to capture everything)
if [[ -n "$PROFILE_STARTUP" ]]; then
  zprof
fi
