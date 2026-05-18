{ lib, ... }:
{
  # Workaround for a recurring home-manager + nix-darwin quirk: when the
  # sops-nix plist content changes (new/removed secrets, new sops-nix-user
  # script path), home-manager's setupLaunchAgents step often fails to replace
  # the on-disk plist at ~/Library/LaunchAgents/, so launchd keeps running the
  # OLD sops-nix-user script and new secrets never materialize. Forces an
  # atomic replace + reload after sops-nix activation.
  home.activation.reloadSopsNixLaunchd = lib.hm.dag.entryAfter [ "sops-nix" ] ''
    PLIST_NAME="org.nix-community.home.sops-nix.plist"
    PLIST_TARGET="$HOME/Library/LaunchAgents/$PLIST_NAME"
    PLIST_SRC="$newGenPath/LaunchAgents/$PLIST_NAME"
    if [ -f "$PLIST_SRC" ] && ! cmp -s "$PLIST_SRC" "$PLIST_TARGET" 2>/dev/null; then
      cp -f "$PLIST_SRC" "$PLIST_TARGET"
      launchctl unload "$PLIST_TARGET" 2>/dev/null || true
      launchctl load "$PLIST_TARGET" 2>/dev/null || true
      # Run the now-current sops-nix-user directly so new secrets materialize
      # immediately rather than at next login. /usr/bin must be on PATH so
      # sops-install-secrets can exec getconf for DARWIN_USER_TEMP_DIR.
      SOPS_SCRIPT=$(grep -oE '/nix/store/[a-z0-9]+-sops-nix-user' "$PLIST_TARGET" | head -1)
      [ -x "$SOPS_SCRIPT" ] && PATH="/usr/bin:/bin:$PATH" "$SOPS_SCRIPT" || true
    fi
  '';
}
