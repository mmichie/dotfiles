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

    # pyenv init, cached with the same _refresh_cache pattern as
    # 50-integrations.zsh — this file is sourced from ~/.zshrc.local, after
    # the lib modules, so the helper and SHELL_CACHE_DIR exist. The previous
    # eval "$(pyenv init --path)" + eval "$(pyenv init -)" pair spawned pyenv
    # twice (~170ms) and each emitted script ran `pyenv rehash` (~250ms each)
    # on every shell — ~700ms, ~90% of startup.
    #   --no-rehash: shims already sit on disk; pyenv install/uninstall run
    #     rehash themselves, so a rehash per shell start buys nothing.
    #   --no-push-path: emits a fork-free "prepend if absent" PATH guard
    #     instead of a bash subprocess dedup dance (~11ms per shell).
    #   explicit zsh: the cached script must not depend on which shell
    #     happened to run the generation.
    # `init --path` is dropped rather than cached: its one distinct effect
    # was the shims PATH prepend, handled below.
    if command -v pyenv &>/dev/null; then
        # Force shims to the FRONT every shell, not just when absent: nested
        # shells (tmux panes, exec zsh) inherit shims mid-PATH and .zshenv's
        # setup_path re-fronts homebrew/nix above them — an absent-only guard
        # would leave `python3` resolving to homebrew's, not the shim. The
        # old `pyenv init -` bash dance did this same strip-and-prepend;
        # typeset -U path (keep-first dedup) makes it one fork-free line.
        path=("$PYENV_ROOT/shims" $path)
        if (( $+functions[_refresh_cache] )); then
            _pyenv_cache="$SHELL_CACHE_DIR/pyenv-init.zsh"
            _refresh_cache "$_pyenv_cache" \
                'pyenv init - --no-rehash --no-push-path zsh' \
                "$commands[pyenv]" \
                && source "$_pyenv_cache"
            unset _pyenv_cache
        else
            # Sourced outside the dotfiles zshrc — slow but functional.
            eval "$(pyenv init - --no-rehash --no-push-path zsh)"
        fi
    fi
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
