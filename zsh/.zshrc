#!/bin/zsh

# Prevent multiple sourcing
[[ "${(P)ZSHRC_LOADED}" == "true" ]] && return
export ZSHRC_LOADED=true

# Exit if not running interactively
[[ $- != *i* ]] && return

# CRITICAL: Set up Homebrew PATH first, before anything else
if [[ -x "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Source global definitions if available
[[ -f /etc/zshrc ]] && source /etc/zshrc

# First source the functions file as it contains base functions needed by other modules
[[ -f ~/.zsh_functions ]] && source ~/.zsh_functions

# Then source core modules in order
for module in platform environment prompt ssh; do
    [[ -f ~/.zsh/lib/${module}.zsh ]] && source ~/.zsh/lib/${module}.zsh
done

# Source function modules
for module in tips system_health; do
    [[ -f ~/.zsh/functions/${module}.zsh ]] && source ~/.zsh/functions/${module}.zsh
done

# Setup hooks
autoload -Uz add-zsh-hook
add-zsh-hook precmd osc7_cwd
case $TERM in
    xterm* | screen*)
        add-zsh-hook precmd update_ps1
        ;;
esac

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
