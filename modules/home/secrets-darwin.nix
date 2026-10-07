{ lib, ... }:
{
  # On a fresh machine ~/Library/LaunchAgents does not exist yet, and sops-nix's
  # own activation entry runs `launchctl bootstrap gui/$UID
  # ~/Library/LaunchAgents/<plist>` BEFORE home-manager's setupLaunchAgents
  # installs that plist. bootstrap fails with EIO, and errexit aborts activation
  # right there — before setupLaunchAgents ever runs — so the plist is never
  # installed and every later switch fails at the identical spot. Seed the
  # directory and the plist ahead of sops-nix to break that deadlock. Only
  # writes when the plist is absent; updateSopsNixLaunchAgent below owns
  # updates.
  home.activation.seedSopsNixLaunchAgent =
    lib.hm.dag.entryBetween [ "sops-nix" ] [ "writeBoundary" ]
      ''
        PLIST_NAME="org.nix-community.home.sops-nix.plist"
        PLIST_SRC="$newGenPath/LaunchAgents/$PLIST_NAME"
        PLIST_DIR="$HOME/Library/LaunchAgents"
        if [ -f "$PLIST_SRC" ] && [ ! -f "$PLIST_DIR/$PLIST_NAME" ]; then
          mkdir -p "$PLIST_DIR"
          cp -f "$PLIST_SRC" "$PLIST_DIR/$PLIST_NAME"
        fi
      '';

  # When the sops-nix plist changes (new/removed secrets, new sops-nix-user
  # script path), the sops-nix entry has just bootstrapped the OLD plist still
  # on disk (the same ordering as above), so the OLD sops-nix-user script ran
  # and new secrets never materialize. Install the new plist and run the new
  # script directly.
  #
  # No launchctl reload: the agent is RunAtLoad with KeepAlive=false, so its
  # loaded definition is only read when it is loaded, and the next load (login,
  # or the sops-nix entry on the next switch) reads the new plist from disk.
  # Installing it here also makes setupLaunchAgents, which runs next, see it as
  # unchanged and skip its own bootout and bootstrap of an agent sops-nix has
  # only just started.
  home.activation.updateSopsNixLaunchAgent = lib.hm.dag.entryAfter [ "sops-nix" ] ''
    PLIST_NAME="org.nix-community.home.sops-nix.plist"
    PLIST_TARGET="$HOME/Library/LaunchAgents/$PLIST_NAME"
    PLIST_SRC="$newGenPath/LaunchAgents/$PLIST_NAME"
    if [ -f "$PLIST_SRC" ] && ! cmp -s "$PLIST_SRC" "$PLIST_TARGET" 2>/dev/null; then
      cp -f "$PLIST_SRC" "$PLIST_TARGET"
      # Run the now-current sops-nix-user directly so new secrets materialize
      # immediately rather than at next login. /usr/bin must be on PATH so
      # sops-install-secrets can exec getconf for DARWIN_USER_TEMP_DIR.
      SOPS_SCRIPT=$(grep -oE '/nix/store/[a-z0-9]+-sops-nix-user' "$PLIST_TARGET" | head -1)
      [ -x "$SOPS_SCRIPT" ] && PATH="/usr/bin:/bin:$PATH" "$SOPS_SCRIPT" || true
    fi
  '';
}
