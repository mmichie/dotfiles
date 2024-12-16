#!/bin/zsh

# Prevent multiple sourcing
[[ "${(P)ZSHRC_LOADED}" == "true" ]] && return
export ZSHRC_LOADED=true

# Exit if not running interactively
[[ $- != *i* ]] && return

# Initialize completions properly first
autoload -Uz compinit
compinit

# CRITICAL: Set up Homebrew PATH first
if [[ -x "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Source global definitions if available
[[ -f /etc/zshrc ]] && source /etc/zshrc

# Source each module exactly once with simple tracking
declare -A LOADED_MODULES

# Core modules first
for module in platform environment shell prompt ssh; do
    if [[ -z ${LOADED_MODULES[$module]} ]]; then
        if [[ -f "$HOME/.zsh/lib/${module}.zsh" ]]; then
            source "$HOME/.zsh/lib/${module}.zsh"
            LOADED_MODULES[$module]=1
        fi
    fi
done

# Function modules
for module in tips system_health; do
    if [[ -z ${LOADED_MODULES[$module]} ]]; then
        if [[ -f "$HOME/.zsh/functions/${module}.zsh" ]]; then
            source "$HOME/.zsh/functions/${module}.zsh"
            LOADED_MODULES[$module]=1
        fi
    fi
done

# Setup hooks
autoload -Uz add-zsh-hook
add-zsh-hook precmd osc7_cwd
[[ $TERM == (xterm*|screen*) ]] && add-zsh-hook precmd update_ps1

# Verify critical commands are available
if ! command -v gum >/dev/null 2>&1; then
    echo "Warning: gum not found. Please run: brew install gum"
    return 1
fi

# Initialize core functionality
init_platform
setup_environment
init_shell

# Ensure history backup
ensure_cron_job_exists

# Additional setup
setup_pyenv
[[ -x "$HOME/bin/fzf" ]] && source <("$HOME/bin/fzf" --zsh)

# Load work profile if available
[[ -f "$HOME/.bash_work_profile" ]] && source "$HOME/.bash_work_profile"

# Show shell status
notify_shell_status
