final: prev: {
  recs = final.callPackage ../pkgs/recs { };
  obliviate = final.callPackage ../pkgs/obliviate { };

  # nixpkgs rclone 1.74.2 always builds with the cmount tag on Darwin but
  # supplies no fuse headers, so cgofuse fails on <fuse.h>. Disable cmount
  # on macOS until upstream fixes the derivation.
  rclone = prev.rclone.override {
    enableCmount = !prev.stdenv.hostPlatform.isDarwin;
  };

  # nixpkgs pipx 1.8.0 tests assert the old `name@ url` form, but the bundled
  # `packaging` now emits `name @ url`. Skip the affected unit tests.
  pipx = prev.pipx.overridePythonAttrs (old: {
    disabledTests = (old.disabledTests or [ ]) ++ [
      "test_fix_package_name"
      "test_parse_specifier_for_metadata"
    ];
  });
}
