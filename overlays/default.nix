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

  # GAM 7.43.04's wheel pins `chardet==5.2.0`, but nixpkgs now ships chardet
  # 6.0.0, so pythonRuntimeDepsCheckHook aborts the build. chardet is only used
  # for charset autodetection (`chardet.detect`, stable across 5.x -> 6.x);
  # relax the exact pin so the runtime-deps check accepts the resolved 6.x.
  gam = prev.gam.overridePythonAttrs (old: {
    pythonRelaxDeps = (old.pythonRelaxDeps or [ ]) ++ [ "chardet" ];
  });

  # nixpkgs statix 0.5.8-unstable-2026-06-28 ships stale insta snapshots for
  # two collapsible_let_in fixtures, so its own `cargo test` fails and the
  # build aborts. Skip just those two cases until upstream regenerates the
  # snapshots (`checkFlags` are forwarded to the libtest harness).
  statix = prev.statix.overrideAttrs (old: {
    checkFlags = (old.checkFlags or [ ]) ++ [
      "--skip=collapsible_let_in_2e638014232f7dec2606c940ad2e97f6_lint"
      "--skip=collapsible_let_in_950e48dec6590cd20937e48006bff3f7_fix"
    ];
  });
}
