# .bash_profile
# The shell sources this file at every interactive login, and any time
# you specify "--login" on the command line.

if [ -f ~/.bashrc ]; then
       source ~/.bashrc
fi

test -e "${HOME}/.iterm2_shell_integration.bash" && source "${HOME}/.iterm2_shell_integration.bash"

#CHEF.NO.SOURCE
