#!/bin/bash

# Constants
readonly BASHRC_LOADED="bashrc_loaded"
readonly SSH_HOSTNAMES=("mattmichie-mbp" "matt-pc" "miley" "matt-pc-wsl")
readonly SSH_ENV="$HOME/.ssh/environment"

# Prevent multiple sourcing
[[ "${!BASHRC_LOADED}" == "true" ]] && return
export "$BASHRC_LOADED=true"

# Exit if not running interactively
case $- in
    *i*) ;;
    *) return ;;
esac

# Source global definitions if available
if [[ -f /etc/bashrc ]]; then
    source /etc/bashrc
fi

# Load shell functions
if [[ -f "$HOME/.bash_functions" ]]; then
    source "$HOME/.bash_functions"
fi

# Detect shell platform
SHELL_PLATFORM=$(detect_shell_platform)
export SHELL_PLATFORM

# SSH agent handling
if [[ " ${SSH_HOSTNAMES[*]} " =~ $(hostname) ]]; then
    handle_ssh_agent
fi

# Update PS1 prompt
unset USERNAME
case $TERM in
    xterm* | screen*)
        PROMPT_COMMAND="update_ps1; $PROMPT_COMMAND"
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

# Completions
setup_completions

# Check and ensure the cron job for history backup is present
ensure_cron_job_exists

# Load work-specific profile if available
if [[ -f "$HOME/.bash_work_profile" ]]; then
    source "$HOME/.bash_work_profile"
fi

# pyenv setup
setup_pyenv
