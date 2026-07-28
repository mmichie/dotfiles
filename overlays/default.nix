final: prev: {
  recs = final.callPackage ../pkgs/recs { };
  obliviate = final.callPackage ../pkgs/obliviate { };
  sckrec = final.callPackage ../pkgs/sckrec { };

  # nixpkgs only packages beads 1.0.3 (embedded-Dolt era); bump to v1.1.0 for
  # the matured `dolt sql-server` + remote model (`bd dolt remote/push/pull`).
  # Source + vendor hashes updated together. Drop this override once nixpkgs
  # ships beads >= 1.1.0.
  #
  # This is the only override here that pins a VERSION rather than patching a
  # build, so it is the only one whose staleness is dangerous: once nixpkgs
  # passes 1.1.0 the pin silently becomes a downgrade. The assert converts that
  # into a hard eval failure on the next flake update instead.
  beads =
    assert prev.lib.assertMsg (prev.lib.versionOlder prev.beads.version "1.1.0")
      "beads override obsolete: nixpkgs now ships beads ${prev.beads.version} (>= 1.1.0). Delete the beads override in overlays/default.nix.";
    prev.beads.overrideAttrs (_: {
      version = "1.1.0";
      src = final.fetchFromGitHub {
        owner = "gastownhall";
        repo = "beads";
        tag = "v1.1.0";
        hash = "sha256-+dFV//0N8ZDw9BHOJOoWZ+BvLmJKlnGtONHIYPRhfBE=";
      };
      vendorHash = "sha256-WWEwGpCwMPD7jaz02zN745RQQqYTQttehbcT3J9hayM=";
      # The v1.1.0 tag's cmd/bd suite fails inside the x86_64-linux build
      # sandbox (nix keeps only the log tail, so the failing cases are not
      # named in CI). The override exists for the binary; upstream CI owns
      # the test suite, and the assert above bounds this override's life.
      doCheck = false;
    });

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
