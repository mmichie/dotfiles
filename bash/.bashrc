# .bashrc
# The shell sources this file during any interactive, non-login
# invocation of "bash".  In other words, any time you run bash in
# sub-shell, this gets run.

# Source global definitions
if [ -f /etc/bashrc ]; then
	. /etc/bashrc
fi

export PATH=$PATH:~/bin
export P4CONFIG=.p4config
export P4EDITOR=vim
export EDITOR=vim
#export LANG=C
export LC_ALL=en_US.UTF-8  
export LANG=en_US.UTF-8
# Aliases
#alias ls="ls --color=auto"
alias ls="ls -G"
alias grep='grep --color=auto -d skip'
alias grpe='grep --color=auto -d skip'
alias ssh="ssh -A -C -o StrictHostKeyChecking=no"
alias nsr='netstat -rn '
alias nsa='netstat -an | sed -n "1,/Active UNIX domain sockets/ p"'
# lsock: to display open sockets (the -P option to lsof disables port names)
alias lsock='sudo /usr/sbin/lsof -i -P'
# to read a single key press:
alias keypress='read -s -n1 keypress; echo $keypress'
alias :='cd ..'
alias ::='cd ../..'
alias :::='cd ../../..'
alias ::::='cd ../../../..'
alias :::::='cd ../../../../..'
alias ::::::='cd ../../../../../..'
# Disable stupid bell
#setterm -blength 0

# Functions

# http_headers: get just the HTTP headers from a web page (and its redirects)
http_headers() { 
    /usr/bin/curl -I -L $@ 
}

sshtunnel() {                                                                      
 if [ $# -ne 3 ] ; then                                                          
    echo "usage: sshtunnel host remote-port local-port"                          
 else                                                                            
    /usr/bin/ssh $1 -L $3:localhost:$2                                           
 fi                                                                              
}

# Shell Options
shopt -s histappend
shopt -s cmdhist
shopt -s checkwinsize
shopt -s execfail

# History
export HISTCONTROL=ignoreboth
export HISTSIZE=10000
export HISTIGNORE="&:ls:[bf]g:exit"

if [ "$TERM" != "dumb" ]; then
    [ -e "$HOME/.dircolors" ] && DIR_COLORS="$HOME/.dircolors"
    [ -e "$DIR_COLORS" ] || DIR_COLORS=""
    eval "`dircolors -b $DIR_COLORS`"
fi

SSH_ENV="$HOME/.ssh/environment"

################################################################################
# READLINE
################################################################################

set -o vi
# For those who want to use Vi bindings in bash, this corrects a
# few annoyances:
#
# 1) up and down arrows retrieve history lines even in insert mode
# 2) left and right arrows work in insert mode
# 3) Ctrl-A and Ctrl-E work how you expect if you have had to
# live in Emacs mode in the past.
# 4) So does Ctrl-D.
 
## Command-mode bindings
# Ctrl-A or Home: insert at line beginning like in emacs mode
bind -m vi-command 'Control-a: vi-insert-beg'
# Ctrl-E or End: append at line end like in emacs mode
bind -m vi-command 'Control-e: vi-append-eol'
# to switch to emacs editing mode
bind -m vi-command '"ZZ": emacs-editing-mode'
 
## Insert-mode bindings
# up arrow or PgUp: append to previous history line
bind -m vi-insert '"\M-[A": ""' # <---- CTRL-P CTRL-E
bind -m vi-insert '"\M-[5~": ""' #<---- CTRL-P CTRL-E
bind -m vi-insert 'Control-p: previous-history'
# dn arrow or PgDn: append to next history line
bind -m vi-insert '"\M-[B": ""' #<---- CTRL-P CTRL-E
bind -m vi-insert '"\M-[6~": ""' #<---- CTRL-P CTRL-E
bind -m vi-insert 'Control-n: next-history'
# Ctrl-A: insert at line start like in emacs mode
bind -m vi-insert 'Control-a: beginning-of-line'
# Ctrl-E: append at line end like in emacs mode
bind -m vi-insert 'Control-e: end-of-line'
# Ctrl-D: delete character
bind -m vi-insert 'Control-d: delete-char'
# Ctrl-L: clear screen
bind -m vi-insert 'Control-l: clear-screen'
 
## Emacs bindings
# Meta-V: go back to vi editing
bind -m emacs '"\ev": vi-editing-mode'

# Completions
complete -A setopt set
complete -A user groups id
complete -A binding bind
complete -A helptopic help
complete -A alias {,un}alias
complete -A signal -P '-' kill
complete -A stopped -P '%' fg bg
complete -A job -P '%' jobs disown
complete -A variable readonly unset
complete -A file -A directory ln chmod
complete -A user -A hostname finger pinky
complete -A directory find cd pushd {mk,rm}dir
complete -A file -A directory -A user chown
complete -A file -A directory -A group chgrp
complete -o default -W 'Makefile' -P '-o ' qmake
complete -A command man which whatis whereis sudo info apropos
complete -A file {,z}cat pico nano vi {,{,r}g,e,r}vi{m,ew} vimdiff elvis emacs {,r}ed e{,x} joe jstar jmacs rjoe jpico {,z}less {,z}more p{,g}