#!/bin/zsh

# Shell orchestration — individual setup_* functions live in dedicated
# modules (history, aliases, completion, keybindings, ls, integrations);
# init_shell below is called from .zshrc after all modules are sourced.

setup_shell_options() {
    setopt interactive_comments
    setopt long_list_jobs
    setopt prompt_subst
    setopt AUTO_CD              # If command is a directory name, cd into it
    setopt AUTO_PUSHD          # Make cd push old directory onto directory stack
    setopt PUSHD_IGNORE_DUPS   # Don't push multiple copies of same directory
    setopt PUSHD_SILENT        # Don't print directory stack after pushd/popd
    setopt EXTENDED_GLOB       # Use extended globbing syntax
    setopt GLOB_DOTS            # Include dotfiles in glob matches without needing .*
    setopt NO_CASE_GLOB        # Case insensitive globbing
    setopt NUMERIC_GLOB_SORT   # Sort filenames numerically when possible
    setopt NO_BEEP             # Don't beep on error
    setopt NO_FLOW_CONTROL     # Disable Ctrl-S/Ctrl-Q flow control (frees those keys)
    setopt CORRECT             # Command correction prompt
    setopt COMPLETE_IN_WORD    # Complete from both ends of word
    setopt ALWAYS_TO_END       # Move cursor to end of word after completion
}

init_shell() {
    setup_shell_options
    setup_aliases
    setup_dircolors
    setup_readline
    setup_completions
    setup_history
    # eza with internal fallback to setup_ls_colors when eza is absent
    setup_eza
    setup_zoxide
}
