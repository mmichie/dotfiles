{ pkgs, ... }:
{
  home.packages = [ pkgs.yarn ];

  # pyenv + Python C-ext build flags. Sourced from ~/.zshrc.local — add:
  #   [[ -f ~/.config/zsh/moab-env.sh ]] && source ~/.config/zsh/moab-env.sh
  xdg.configFile."zsh/moab-env.sh".text = ''
    export PYENV_ROOT="$HOME/.pyenv"
    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"
    eval "$(pyenv virtualenv-init -)"

    # Keg-only versioned formula — expose psql, pg_ctl, etc.
    export PATH="/opt/homebrew/opt/postgresql@18/bin:$PATH"

    export LIBMEMCACHED=/opt/homebrew/opt/libmemcached
    export CPPFLAGS="-I/opt/homebrew/opt/libmemcached/include -I/opt/homebrew/opt/graphviz/include"
    export LDFLAGS="-L/opt/homebrew/opt/libmemcached/lib -L/opt/homebrew/opt/graphviz/lib"
  '';
}
