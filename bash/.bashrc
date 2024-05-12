#!/bin/bash

# Prevent multiple sourcing
[[ "$BASHRC_LOADED" == "true" ]] && return
BASHRC_LOADED=true

# Exit if not running interactively
[[ $- != *i* ]] && return

# Source global definitions if available
[[ -f /etc/bashrc ]] && source /etc/bashrc

# User specific environment and startup programs
export HOMEBREW_NO_ANALYTICS=1

# Load shell functions
source "$HOME/.bash_functions"

# Detect shell platform
SHELL_PLATFORM=$(detect_shell_platform)

# SSH agent handling
HOSTNAME=$(hostname)
declare -a SSH_HOSTNAMES=("mattmichie-mbp" "matt-pc" "miley" "matt-pc-wsl")

if [[ " ${SSH_HOSTNAMES[@]} " =~ " $HOSTNAME " ]]; then
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

SSH_ENV="$HOME/.ssh/environment"

# Readline setup
setup_readline

# Completions
setup_completions

test -e "${HOME}/.bash_work_profile" && source "${HOME}/.bash_work_profile"

# Add RVM to PATH for scripting. Make sure this is the last PATH variable change.
export PATH="$PATH:$HOME/.rvm/bin"

# pyenv setup
setup_pyenv
