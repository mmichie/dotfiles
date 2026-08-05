{
  lib,
  pkgs,
  config,
  mkLink,
  ...
}:
{
  home.file = {
    ".gitconfig".source = mkLink "git/.gitconfig";
    ".gitignore_global".source = mkLink "git/.gitignore_global";
  }
  // lib.optionalAttrs config.my.isWork {
    ".gitconfig-kyusu-local".source = mkLink "git/.gitconfig-kyusu-local";
  };

  # configs/git/.gitconfig sets core.hooksPath globally, so git ignores
  # .git/hooks and there is no per-clone hook install — a fresh machine would
  # silently run no hooks at all (lefthook never wired in). Sync lefthook's shims
  # into the configured hooksPath on every switch. --force is required because
  # lefthook refuses to touch a globally-set hooksPath; the install is
  # idempotent. Guarded on the repo being present. The activation PATH is
  # minimal and has no git, but lefthook shells out to it, so prepend it.
  home.activation.installGitHooks = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if [ -d "${config.my.dotfilesRoot}/.git" ]; then
      ( cd "${config.my.dotfilesRoot}" \
          && PATH="${pkgs.git}/bin:$PATH" "${pkgs.lefthook}/bin/lefthook" install --force ) \
        || echo "installGitHooks: lefthook install failed (git hooks may be inactive)"
    fi

    # A global hooksPath means these shims also run in repositories that no
    # human created: notably the BARE cache-mirror repo Dolt builds for a
    # git-backed remote (beads' `bd dolt push`). lefthook's shim ends in an
    # unconditional `call_lefthook run <hook>`, and lefthook requires a work
    # tree, so it aborts with "fatal: this operation must be run in a work
    # tree" and takes the enclosing operation down with it. That is upstream
    # beads #3724/#4272, where the same crash is reported via init.templateDir.
    #
    # Gate every shim on actually being inside a work tree. `lefthook install
    # --force` above rewrites the shims each switch, so this re-applies after
    # it, and is idempotent. Exiting 0 is deliberate: no work tree means no
    # hooks to run, which is success, not a blocked operation.
    hooksDir="$(PATH="${pkgs.git}/bin:$PATH" git config --get core.hooksPath || true)"
    case "$hooksDir" in
      "~/"*) hooksDir="$HOME/''${hooksDir#\~/}" ;;
    esac
    if [ -n "$hooksDir" ] && [ -d "$hooksDir" ]; then
      for hook in "$hooksDir"/*; do
        [ -f "$hook" ] || continue
        grep -q 'is-inside-work-tree' "$hook" && continue
        head -n 1 "$hook" | grep -q '^#!' || continue
        sed -i '1a [ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" = "true" ] || exit 0' "$hook"
      done
    fi
  '';
}
