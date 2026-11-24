# AeroSpace's config, generated in full. The desktops, their Cmd+N and
# Alt+Cmd+N keys and the app rules come from lib/desktops.nix, which dwm in
# the NixOS VM reads too; everything AeroSpace-only is below. A switch writes
# ~/.config/aerospace/aerospace.toml; AeroSpace reads it on start or on
# `aerospace reload-config` (Cmd+Shift+semicolon, then Esc).
{ lib, pkgs, ... }:
let
  inherit (import ../../lib/desktops.nix) desktops apps floating;

  # Cmd+N shows desktop N, Alt+Cmd+N moves the window there. Alt+Cmd rather
  # than dwm's Mod+Shift: Cmd+Shift+3/4/5 are macOS's screenshot keys.
  desktopKeys = lib.listToAttrs (
    lib.concatMap (d: [
      (lib.nameValuePair "cmd-${d}" "workspace ${d}")
      (lib.nameValuePair "alt-cmd-${d}" "move-node-to-workspace ${d}")
    ]) desktops
  );

  # Each app with a bundle id goes to its desktop, in desktop order.
  desktopRules = lib.concatMap (
    d:
    map (app: {
      "if".app-id = app.macos;
      run = lib.optional (app.tile or false) "layout tiling" ++ [ "move-node-to-workspace ${d}" ];
    }) (lib.filter (app: app ? macos) (apps.${d} or [ ]))
  ) desktops;

  # One rule floats them all, matching display names with a verbose ((?x))
  # regex: an alternative per line, spaces escaped since (?x) ignores bare
  # whitespace.
  floatingRule = {
    "if".app-name-regex-substring =
      "(?x)^(\n    "
      + lib.concatMapStringsSep "\n  | " (app: lib.replaceStrings [ " " ] [ "\\ " ] app.macosName) (
        lib.filter (app: app ? macosName) floating
      )
      + "\n)$";
    run = "layout floating";
  };

  settings = {
    config-version = 2;

    # Auto-start settings
    after-login-command = [ ];
    after-startup-command = [ ];
    start-at-login = true;

    # DWM-like window management behavior
    enable-normalization-flatten-containers = true;
    enable-normalization-opposite-orientation-for-nested-containers = true;

    # DWM uses master-stack layout by default
    default-root-container-layout = "tiles";
    default-root-container-orientation = "horizontal";
    # Non-zero so an accidental accordion (cmd-shift-i / cmd-shift-d /
    # cmd-semicolon) shows as visibly offset windows instead of an invisible
    # stack.
    accordion-padding = 30;

    # Keep the desktops alive when empty; config-version 2 no longer infers
    # them from the bindings.
    persistent-workspaces = desktops;

    # Mouse behavior (DWM-like)
    on-focused-monitor-changed = [ "move-mouse monitor-lazy-center" ];

    # A VM brings its own window manager. While a UTM guest window has focus,
    # switch to a mode with no bindings, so the cmd-* chords below reach the
    # guest (dwm in the NixOS VM uses the same ones). UTM's "capture input"
    # does not do this: AeroSpace's hotkeys fire first with capture on or off.
    # UTM's library window, whose title starts with "UTM", keeps the normal
    # bindings.
    on-focus-changed = [
      ''exec-and-forget case "$(aerospace list-windows --focused --format "%{app-bundle-id} %{window-title}")" in "com.utmapp.UTM UTM"*) want=main ;; "com.utmapp.UTM "*) want=guest ;; *) want=main ;; esac; have=$(aerospace list-modes --current); [ "$want$have" = guestmain ] && aerospace mode guest; [ "$want$have" = mainguest ] && aerospace mode main''
    ];
    automatically-unhide-macos-hidden-apps = false;

    # DWM uses zero gaps by default
    gaps = {
      inner = {
        horizontal = 0;
        vertical = 0;
      };
      outer = {
        left = 0;
        bottom = 0;
        top = 0;
        right = 0;
      };
    };

    key-mapping.preset = "qwerty";

    mode = {
      # Main mode bindings (following dwm's default mod key paradigm)
      main.binding = desktopKeys // {
        # Layouts (dwm-style), moved off keys macOS apps use
        cmd-y = "layout tiles horizontal vertical"; # not cmd-t: "New Tab"
        cmd-u = "layout floating tiling"; # not cmd-f: "Find"
        cmd-tab = "layout tiles horizontal vertical";
        cmd-semicolon = "layout tiles accordion floating"; # cycle; not cmd-space: Spotlight
        cmd-shift-f = "fullscreen";

        # Basic window operations (dwm-style)
        cmd-shift-c = "close"; # dwm's default
        cmd-j = "focus down"; # next window
        cmd-k = "focus up"; # previous window
        cmd-h = "focus left";
        cmd-l = "focus right";
        cmd-shift-j = "move down"; # move window forward
        cmd-shift-k = "move up"; # move window backward

        # Master/stack operations (approximating dwm behavior)
        cmd-i = "resize smart +50"; # grow master area
        cmd-d = "resize smart -50"; # shrink master area
        cmd-enter = "move left"; # move to master position
        cmd-shift-i = "layout h_accordion"; # more masters (approximation)
        cmd-shift-d = "layout v_accordion"; # fewer masters (approximation)

        # Desktops beyond desktopKeys
        cmd-alt-left = "workspace prev";
        cmd-alt-right = "workspace next";
        cmd-backtick = "workspace-back-and-forth"; # last desktop

        # Monitor controls
        cmd-comma = "focus-monitor prev";
        cmd-period = "focus-monitor next";
        cmd-shift-comma = "move-workspace-to-monitor prev";
        cmd-shift-period = "move-workspace-to-monitor next";

        # Service mode for additional controls
        cmd-shift-semicolon = "mode service";
      };

      # Guest mode: no bindings at all. on-focus-changed above enters it while
      # a UTM guest window has focus and leaves it when focus moves elsewhere.
      guest.binding = { };

      service.binding = {
        esc = [
          "reload-config"
          "mode main"
        ];
        r = [
          "flatten-workspace-tree"
          "mode main"
        ]; # reset layout
        backspace = [
          "close-all-windows-but-current"
          "mode main"
        ];

        # Monitor joining (similar to dwm's merge functionality)
        cmd-shift-h = [
          "join-with left"
          "mode main"
        ];
        cmd-shift-j = [
          "join-with down"
          "mode main"
        ];
        cmd-shift-k = [
          "join-with up"
          "mode main"
        ];
        cmd-shift-l = [
          "join-with right"
          "mode main"
        ];
      };

      # Gaps mode (switch between preset gaps configurations)
      gaps.binding = {
        esc = "mode main";
        "0" = [
          ''exec-and-forget osascript -e "do shell script \"defaults write com.nikitabobko.AeroSpace gaps.outer.left 0 && defaults write com.nikitabobko.AeroSpace gaps.outer.right 0 && defaults write com.nikitabobko.AeroSpace gaps.outer.top 0 && defaults write com.nikitabobko.AeroSpace gaps.outer.bottom 0 && defaults write com.nikitabobko.AeroSpace gaps.inner.horizontal 0 && defaults write com.nikitabobko.AeroSpace gaps.inner.vertical 0\""''
          "reload-config"
          "mode main"
        ];
        r = [
          "reload-config"
          "mode main"
        ]; # reset to config defaults
      };
    };

    on-window-detected = desktopRules ++ [
      # Spotify goes to the laptop screen when it is attached. With the lid
      # closed no monitor matches, the callback's error is discarded, and
      # Spotify stays put.
      {
        "if".app-id = "com.spotify.client";
        run = [ "move-node-to-monitor built-in" ];
      }
      floatingRule
    ];
  };
in
{
  xdg.configFile."aerospace/aerospace.toml".source =
    (pkgs.formats.toml { }).generate "aerospace.toml"
      settings;
}
