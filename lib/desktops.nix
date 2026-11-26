# Desktops, and which app opens on which, for both window managers: AeroSpace
# on macOS (modules/home/aerospace.nix) and dwm in the NixOS VM
# (hosts/vm-aarch64/dwm/desktops.nix) generate their config from this file.
# Edit it, then switch the machine whose window manager should pick it up.
let
  # In order. Each name is also its key: Cmd+N (AeroSpace) or Mod+N (dwm)
  # shows desktop N; Alt+Cmd+N or Mod+Shift+N moves the window there.
  desktops = [
    "1"
    "2"
    "3"
    "4"
    "5"
    "6"
  ];

  # What dwm's bar shows for each desktop in place of its name: a Nerd Font
  # icon, by hex codepoint, for what opens there (apps, below). AeroSpace has
  # no bar to show them in. A desktop without one shows its name.
  icons = {
    "1" = "f489"; # nf-oct-terminal
    "2" = "f268"; # nf-fa-chrome
    "3" = "f121"; # nf-fa-code
    "4" = "f086"; # nf-fa-comments
    "5" = "f02d"; # nf-fa-book
    "6" = "f0ae"; # nf-fa-tasks
  };

  # Apps, by the desktop they open on. An app names itself per platform, and
  # needs only the platforms it runs on:
  #   macos  its bundle id, as `aerospace list-apps` prints it
  #   x11    its WM_CLASS, as `xprop WM_CLASS` prints it (instance first,
  #          then class), given as { class = ...; } or { instance = ...; };
  #          and exec, a command as a list of arguments, which dwm runs
  #          when you switch to the desktop and it has no windows (the first
  #          app on a desktop with one)
  #   tile   make AeroSpace tile it rather than float it (macOS only)
  apps = {
    "1" = [
      { macos = "com.apple.Terminal"; }
      { macos = "com.googlecode.iterm2"; }
      {
        macos = "com.github.wez.wezterm";
        x11.class = "org.wezfurlong.wezterm";
      }
      {
        macos = "com.mitchellh.ghostty";
        x11.class = "com.mitchellh.ghostty";
        tile = true;
      }
      { macos = "com.utmapp.UTM"; }
      {
        x11.class = "st-256color";
        # as Mod+Shift+Return (hosts/vm-aarch64/dwm/config.h)
        x11.exec = [
          "/bin/sh"
          "-c"
          "exec st -e \"$HOME/bin/tmux-attach-or-new\""
        ];
      }
      # st in tabbed (Mod+Shift+T in hosts/vm-aarch64/dwm/config.h)
      { x11.class = "tabbed"; }
    ];
    "2" = [
      # By instance on X11: Chrome's app windows (Slack below) share its
      # class, Google-chrome, and only the instance tells them apart.
      {
        macos = "com.google.Chrome";
        x11.instance = "google-chrome";
        x11.exec = [ "google-chrome-stable" ];
        tile = true;
      }
    ];
    "3" = [
      { macos = "com.microsoft.VSCode"; }
      { macos = "com.jetbrains.intellij.ce"; }
      { macos = "com.apple.FinalCut"; }
      { macos = "com.apple.dt.Xcode"; }
      { macos = "com.apple.iphonesimulator"; }
    ];
    "4" = [
      { macos = "com.hnc.Discord"; }
      { macos = "org.whispersystems.signal-desktop"; }
      {
        macos = "com.tinyspeck.slackmacgap";
        # the VM's `slack`: Slack's web app in a Chrome app window
        x11.instance = "app.slack.com__client";
        x11.exec = [ "slack" ];
      }
    ];
    "5" = [
      { macos = "md.obsidian"; }
    ];
    "6" = [
      { macos = "com.linear"; }
      { macos = "com.toggl.toggldesktop"; } # Time tracking
      { macos = "com.jetbrains.datagrip"; }
    ];
  };

  # Apps that float instead of tiling, on whatever desktop is showing.
  #   macosName  the app's display name, as a regex fragment
  #   x11        as for `apps`
  floating = [
    {
      macosName = "1Password ?[0-9]*";
      x11.class = "com.onepassword.OnePassword";
    }
    { macosName = "Activity Monitor"; }
    { macosName = "AirPort Utility"; }
    { macosName = "App Store"; }
    { macosName = "Archive Utility"; }
    { macosName = "Calculator"; }
    { macosName = "Calendar"; }
    { macosName = "ColorSync Utility"; }
    { macosName = "Console"; }
    { macosName = "Contacts"; }
    { macosName = "Disk Utility"; }
    { macosName = "FaceTime"; }
    { macosName = "Finder"; }
    { macosName = "GIMP"; }
    { macosName = "Keychain Access"; }
    { macosName = "Messages"; }
    { macosName = "Migration Assistant"; }
    { macosName = "Photo Booth"; }
    { macosName = "Preview"; }
    { macosName = "QuickTime Player"; }
    { macosName = "Screenshot"; }
    { macosName = "Software Update"; }
    { macosName = "Stickies"; }
    { macosName = "System Information"; }
    { macosName = "System Preferences"; }
    { macosName = "System Settings"; }
    { macosName = "VLC( media player)?"; }
  ];

  # A desktop's name is its key, so it has to be one digit, and every app
  # has to name a desktop that exists.
  bad =
    builtins.filter (d: builtins.match "[1-9]" d == null) desktops
    ++ builtins.filter (d: !builtins.elem d desktops) (builtins.attrNames apps);

  # Every icon has to belong to a desktop and be a codepoint in hex.
  badIcons = builtins.filter (
    d: !builtins.elem d desktops || builtins.match "[0-9a-f]{4,6}" icons.${d} == null
  ) (builtins.attrNames icons);
in
if bad != [ ] then
  throw "lib/desktops.nix: not a desktop (or not a single digit 1-9): ${builtins.concatStringsSep ", " bad}"
else if badIcons != [ ] then
  throw "lib/desktops.nix: an icon for no desktop, or not a hex codepoint: ${builtins.concatStringsSep ", " badIcons}"
else
  {
    inherit
      desktops
      icons
      apps
      floating
      ;
  }
