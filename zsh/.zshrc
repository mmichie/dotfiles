#!/bin/zsh

# Constants
ZSHRC_LOADED="zshrc_loaded"
SSH_HOSTNAMES=("mattmichie-mbp" "matt-pc" "miley" "matt-pc-wsl")
SSH_ENV="$HOME/.ssh/environment"

# Prevent multiple sourcing
[[ "${(P)ZSHRC_LOADED}" == "true" ]] && return
export ZSHRC_LOADED=true

# Exit if not running interactively
[[ $- != *i* ]] && return

# Source global definitions if available
[[ -f /etc/zshrc ]] && source /etc/zshrc

# Load shell functions
[[ -f "$HOME/.zsh_functions" ]] && source "$HOME/.zsh_functions"

# Detect shell platform
SHELL_PLATFORM=$(detect_shell_platform)
export SHELL_PLATFORM

# SSH agent handling
if [[ " ${SSH_HOSTNAMES[*]} " == *$(hostname)* ]]; then
    handle_ssh_agent
fi

# Update PS1 prompt
unset USERNAME
case $TERM in
    xterm* | screen*)
        precmd() {
            update_ps1
        }
        ;;
esac

# Environment setup
setup_environment

# GOPATH setup
setup_gopath

# Platform-specific aliases and setup
setup_platform_specific

# Aliases
setup_aliases

# Shell options
setup_shell_options

# History
setup_history

# Dircolors setup
setup_dircolors

# Readline setup
setup_readline

# Setup completions
setup_completions

# Check and ensure the cron job for history backup is present
ensure_cron_job_exists

# Load work-specific profile if available
[[ -f "$HOME/.bash_work_profile" ]] && source "$HOME/.bash_work_profile"

# pyenv setup
setup_pyenv

[[ -x "$HOME/bin/fzf" ]] && source <("$HOME/bin/fzf" --zsh)

notify_shell_status
