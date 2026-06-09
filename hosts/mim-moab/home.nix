{ pkgs, ... }:
{
  home.packages = [ pkgs.yarn ];

  # This host's work infra repo runs HashiCorp Terraform in CI, so install
  # terraform instead of the default OpenTofu — keeps local state operations
  # compatible with what auto-applies on merge.
  my.iacTool = "terraform";

  # pyenv + Python C-ext build flags. Sourced from ~/.zshrc.local — add:
  #   [[ -f ~/.config/zsh/moab-env.sh ]] && source ~/.config/zsh/moab-env.sh
  xdg.configFile."zsh/moab-env.sh".text = ''
    export PYENV_ROOT="$HOME/.pyenv"
    eval "$(pyenv init --path)"
    eval "$(pyenv init -)"
    # virtualenv-init dropped: its precmd hook calls pyenv on every prompt and
    # uses GNU stat syntax that fails silently on macOS. Activate venvs by hand
    # with `pyenv activate <name>` or `pyenv shell <version>`.

    # Keg-only versioned formula — expose psql, pg_ctl, etc.
    export PATH="/opt/homebrew/opt/postgresql@18/bin:$PATH"

    export LIBMEMCACHED=/opt/homebrew/opt/libmemcached
    export CPPFLAGS="-I/opt/homebrew/opt/libmemcached/include -I/opt/homebrew/opt/graphviz/include"
    export LDFLAGS="-L/opt/homebrew/opt/libmemcached/lib -L/opt/homebrew/opt/graphviz/lib"
  '';
}
