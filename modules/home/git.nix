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
  # silently run no hooks (no lefthook, no secret-scan). Sync lefthook's shims
  # into the configured hooksPath on every switch. --force is required because
  # lefthook refuses to touch a globally-set hooksPath; the install is
  # idempotent. Guarded on the repo being present.
  home.activation.installGitHooks = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if [ -d "${config.my.dotfilesRoot}/.git" ]; then
      ( cd "${config.my.dotfilesRoot}" \
          && "${pkgs.lefthook}/bin/lefthook" install --force ) \
        || echo "installGitHooks: lefthook install failed (git hooks may be inactive)"
    fi
  '';
}
