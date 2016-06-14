# .bash_profile
# The shell sources this file at every interactive login, and any time
# you specify "--login" on the command line.

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi

# User specific environment and startup programs

PATH=$PATH:$HOME/bin
export PATH

unset USERNAME
case $TERM in
    (xterm*)
        PROMPT_COMMAND='echo -ne "\033]0;${HOSTNAME}: ${PWD}\007"' ;;
esac


