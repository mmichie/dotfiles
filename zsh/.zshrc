#!/bin/zsh

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

# Load completion system
autoload -Uz compinit
compinit -i

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

# Initialize Homebrew if available
if [[ -x "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
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
    "shell"              # Shell configuration
    "prompt"             # Prompt setup
    "ssh"                # SSH configuration
    "utils"              # Utility functions
)

for module in "${core_modules[@]}"; do
    load_module "lib" "$module"
done

# Load function modules
function_modules=(
    "tips"
    "status"
    "system_health"
)

for module in "${function_modules[@]}"; do
    load_module "function" "$module"
done

# Initialize core components
setup_environment
init_shell
init_prompt

# Setup FZF if available
if [[ -x "$HOME/bin/fzf" ]]; then
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

# Ensure backup cron job exists
ensure_cron_job_exists

# Display system status only on initial login shell
if [[ ! -f "/tmp/shell_status_shown_$$" ]]; then
    # Verify gum is available
    if command -v gum >/dev/null 2>&1; then
        notify_shell_status
        touch "/tmp/shell_status_shown_$$"
    else
        echo "Warning: 'gum' command not found. Please install it via: brew install gum"
    fi
fi

# Show daily tip
show_daily_tip

# Final cleanup
unset core_modules function_modules
