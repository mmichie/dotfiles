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

# Set up fpath for zsh functions
() {
    local -a zsh_paths

    # Common paths that might exist
    local -a possible_paths=(
        "/usr/share/zsh/site-functions"
        "/usr/local/share/zsh/site-functions"
        "/opt/homebrew/share/zsh/site-functions"
        "/usr/share/zsh/functions/Completion"
        "/usr/share/zsh/functions/Completion/Unix"
        "/usr/share/zsh/functions/Completion/Linux"
        "/usr/share/zsh/vendor-functions"
        "$SHELL_FUNCTIONS_DIR"
    )

    # Only add paths that exist
    for p in "${possible_paths[@]}"; do
        [[ -d "$p" ]] && zsh_paths+=("$p")
    done

    # Set fpath
    fpath=("${zsh_paths[@]}" $fpath)
}

# Load completion system with caching and optimization
autoload -Uz compinit
# Skip security check for faster startup
compinit -C

# Load compctl module if available
if ! zmodload -e zsh/compctl; then
    zmodload zsh/compctl 2>/dev/null
fi

# Basic autoloads
autoload -Uz compctl

# Create necessary directories
mkdir -p "$SHELL_CACHE_DIR"

# Prevent multiple sourcing
if [[ -n "$ZSH_INITIALIZED" ]]; then
    return 0
fi
export ZSH_INITIALIZED=1

# Lazy load Homebrew - only when brew command is first used
if [[ -x "/opt/homebrew/bin/brew" ]] && [[ -z "$HOMEBREW_PREFIX" ]]; then
    brew() {
        unfunction brew
        eval "$(/opt/homebrew/bin/brew shellenv)"
        brew "$@"
    }
fi

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

# Load core library modules in specific order
core_modules=(
    "platform_detection" # Must be first for platform detection
    "platform_utils"     # Platform-specific utilities
    "executables"        # Executable setup
    "environment"        # Environment setup
    "location_service"   # Location service (SQLite backend)
    "wifi_location"      # WiFi-based location detection with precmd hook
    "shell"              # Shell configuration
    "prompt"             # Prompt setup
    "ssh"                # SSH configuration
    "tmux_emoji_titles"  # Automatic emoji titles for tmux windows
    "utils"              # Utility functions
)

for module in "${core_modules[@]}"; do
    load_module "lib" "$module"
done

# Lazy load function modules
tips() {
    unfunction tips show_daily_tip zsh_hotkeys_help show_tool_tips
    load_module "function" "tips"
    if [[ $# -gt 0 ]]; then
        tips "$@"
    else
        show_daily_tip
    fi
}

system_health() {
    unfunction system_health display_system_health
    load_module "function" "system_health"
    if [[ $# -gt 0 ]]; then
        system_health "$@"
    else
        display_system_health
    fi
}

# Load status module immediately as it's needed for shell startup
load_module "function" "status"

# Load utility functions
load_module "function" "utils"

# Load location CLI commands
load_module "function" "location_cli"

# Initialize core components
setup_environment
init_shell
init_prompt

# Load FZF immediately for key bindings but minimize impact
if [[ -x "$HOME/bin/fzf" ]]; then
    # Source the zsh integration script (includes keybindings)
    source <("$HOME/bin/fzf" --zsh)
fi

# Setup pyenv if available
if [[ -d "$HOME/.pyenv" ]]; then
    setup_pyenv
fi

# Load work profile if it exists
if [[ -f "$HOME/.bash_work_profile" ]]; then
    source "$HOME/.bash_work_profile"
fi

# Display system status only on login shells (not tmux panes or subshells)
if [[ -o login ]]; then
    # Verify gum is available
    if command -v gum >/dev/null 2>&1; then
        notify_shell_status

        # Load tips module and show daily tip
        load_module "function" "tips"
        show_daily_tip
    else
        echo "Warning: 'gum' command not found. Please install it via: brew install gum"
    fi
fi

# Final cleanup
unset core_modules function_modules

# Disable correction for specific commands
CORRECT_IGNORE_FILE='.*|claude'

# Load claude wrapper function
if [[ -f "$SHELL_FUNCTIONS_DIR/claude_wrapper.zsh" ]]; then
    source "$SHELL_FUNCTIONS_DIR/claude_wrapper.zsh"
fi

# Display profiling results if PROFILE_STARTUP is set
if [[ -n "$PROFILE_STARTUP" ]]; then
  zprof
fi

# Initialize atuin for better shell history (only if available)
# Use atuin for history storage but disable its key bindings to use fzf instead
if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init zsh --disable-up-arrow --disable-ctrl-r)"
fi

# macOS path_helper fix: Login shells may have PATH reset by /etc/zprofile
# Simply rebuild to ensure our custom paths are in the correct order
if is_osx && [[ -o login ]]; then
    path_build
fi

# Set up vivid for better ls colors (only if available)
if command -v vivid >/dev/null 2>&1; then
  export LS_COLORS="$(vivid generate tokyonight-night)"
fi

# Note: Google Cloud SDK lazy loading is now handled in environment.zsh

# Source local config (not in dotfiles repo, for secrets/machine-specific settings)
[ -f ~/.zshrc.local ] && source ~/.zshrc.local

alias gam="/Users/mim/bin/gam7/gam"
source /Users/mim/.config/op/plugins.sh
