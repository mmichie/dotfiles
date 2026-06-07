#!/bin/zsh

# Shell options. Set early so EXTENDED_GLOB is on before later modules
# (e.g. _parse_env_file's pattern matching) parse anything that needs it.

setup_shell_options() {
    setopt interactive_comments
    setopt long_list_jobs
    setopt prompt_subst
    setopt AUTO_CD              # If command is a directory name, cd into it
    setopt AUTO_PUSHD          # Make cd push old directory onto directory stack
    setopt PUSHD_IGNORE_DUPS   # Don't push multiple copies of same directory
    setopt PUSHD_SILENT        # Don't print directory stack after pushd/popd
    setopt EXTENDED_GLOB       # Use extended globbing syntax
    # GLOB_DOTS deliberately NOT set: a global "bare * matches dotfiles"
    # makes `rm *` include dotfiles and silently breaks functions and
    # snippets that assume default globbing (it double-counted dotfiles in
    # fs()). Use the (D) glob qualifier where dotfiles are wanted.
    setopt NO_CASE_GLOB        # Case insensitive globbing
    setopt NUMERIC_GLOB_SORT   # Sort filenames numerically when possible
    setopt NO_BEEP             # Don't beep on error
    setopt NO_FLOW_CONTROL     # Disable Ctrl-S/Ctrl-Q flow control (frees those keys)
    setopt CORRECT             # Command correction prompt
    setopt COMPLETE_IN_WORD    # Complete from both ends of word
    setopt ALWAYS_TO_END       # Move cursor to end of word after completion
}

setup_shell_options
