# .bash_profile
# The shell sources this file at every interactive login, and any time
# you specify "--login" on the command line.

# Get the aliases and functions
if [ -f ~/.bashrc ]; then
	. ~/.bashrc
fi

# User specific environment and startup programs

unset USERNAME
case $TERM in
    (xterm*)
        PROMPT_COMMAND='echo -ne "\033]0;${HOSTNAME}: ${PWD}\007"' ;;
esac


export PATH=$HOME/bin:$(brew --prefix)/sbin:$(brew --prefix)/bin:$PATH

export EDITOR=mvim
export UBER_HOME="$HOME/Uber"
export UBER_OWNER="mattm@uber.com"
export UBER_LDAP_UID="mattm"

export VAGRANT_DEFAULT_PROVIDER=aws
[ -s "/usr/local/bin/virtualenvwrapper.sh" ] && . /usr/local/bin/virtualenvwrapper.sh
[ -s "$HOME/.nvm/nvm.sh" ] && . $HOME/.nvm/nvm.sh
type "brew" &>/dev/null && [ -s "$(brew --prefix)/etc/bash_completion" ] && . $(brew --prefix)/etc/bash_completion
if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi

if [ -z "$GOPATH" ]; then
  export GOPATH="$UBER_HOME/go"
  mkdir -p "$GOPATH"
  echo "export GOPATH=\"$GOPATH\"" >> ~/.bash_profile
  echo "export PATH=\"$PATH:$GOPATH/bin\"" >> ~/.bash_profile
fi

cdsync () {
    cd $(boxer sync_dir $@)
}
editsync () {
    $EDITOR $(boxer sync_dir $@)
}
opensync () {
    open $(boxer sync_dir $@)
}

test -e "${HOME}/.iterm2_shell_integration.bash" && source "${HOME}/.iterm2_shell_integration.bash"

export GOPATH="/Users/mattm/Uber/go"
export PATH="/Users/mattm/.nvm/v0.10.32/bin:/Users/mattm/bin:/usr/local/sbin:/usr/local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/X11/bin:/usr/local/MacGPG2/bin:/Users/mattm/Uber/go/bin"
export PATH="/Users/mattm/.nvm/v0.10.32/bin:/Users/mattm/bin:/usr/local/sbin:/usr/local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/X11/bin:/usr/local/MacGPG2/bin:/Users/mattm/bin:/Users/mattm/Uber/go/bin"
