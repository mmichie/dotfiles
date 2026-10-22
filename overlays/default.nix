final: prev: {
  recs = final.callPackage ../pkgs/recs { };
  obliviate = final.callPackage ../pkgs/obliviate { };

  # gremlins: mutation testing for Go. Not in nixpkgs at all, so this is a new
  # package rather than an override — no staleness assert applies, and a nixpkgs
  # bump cannot silently downgrade it. See pkgs/gremlins/default.nix for why it
  # was chosen over go-mutesting (that one has been dormant since 2021).
  gremlins = final.callPackage ../pkgs/gremlins { };

  # Nordwand Mono: a font, also absent from nixpkgs. See pkgs/nordwand-mono.
  nordwand-mono = final.callPackage ../pkgs/nordwand-mono { };

  # CodeQL's Go extractor cannot run on NixOS as nixpkgs packages it. The release
  # zip's tools/linux64/ binaries keep the generic interpreter
  # /lib64/ld-linux-x86-64.so.2, which NixOS refuses to exec:
  #
  #   Could not start dynamically linked executable: .../preload_tracer
  #   Exit status 127 from .../go/tools/autobuild.sh
  #
  # The Go extractor traces the build through preload_tracer, so
  # "codeql database create --language=go" produces a 6K EMPTY database and
  # reports a fatal error. Nothing routes around it: Go rejects
  # --build-mode=none, and nix-ld is not configured on this machine.
  # autoPatchelfHook fixes the three affected binaries; with it, extraction
  # succeeds (verified: a 20M database over the shiprock tree, and a query that
  # reproduces a known defect).
  #
  # This is an UPSTREAM nixpkgs bug and not version-specific — it reproduces on
  # 2.25.6 and 2.26.4 alike, so there is no version to assert against and no
  # staleness check to write. It stays until nixpkgs adopts the hook. Worth
  # reporting upstream: CodeQL's Go extractor is unusable on NixOS out of the box
  # for anyone, not just here.
  #
  # There WAS a second half to this override — a bump to 2.26.4, because 2.25.6
  # cannot fetch the codeql/go-all library pack at all (the registry serves a
  # manifest format it cannot parse, and without that pack no custom Go query
  # compiles). It was dropped when this branch rebased onto the flake bump in
  # 89bce54, which moved nixpkgs to a rev already carrying 2.26.4. Its
  # self-expiring assert fired exactly as intended, which is the argument for
  # writing them.
  # Linux only. The interpreter problem is NixOS's and autoPatchelfHook is an
  # ELF tool; applied on darwin it broke the build of the whole system
  # closure (CI red on macos-latest since this landed, and `darwin-rebuild
  # switch` would have failed the same way). Darwin gets stock codeql, whose
  # Go extractor has no such problem.
  codeql =
    if prev.stdenv.hostPlatform.isLinux then
      prev.codeql.overrideAttrs (old: {
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.autoPatchelfHook ];
        buildInputs = (old.buildInputs or [ ]) ++ [
          final.stdenv.cc.cc.lib
          final.zlib
        ];
        # The bundle carries binaries for languages and helper tools whose shared
        # deps are not all present; the Go extractor path is what this override
        # exists for, and a missing dep on some unrelated tool must not fail the
        # build.
        autoPatchelfIgnoreMissingDeps = true;
      })
    else
      prev.codeql;

  # azure-cli stopped evaluating when nixpkgs moved python3Packages.invoke to
  # 3.0.3. It depends on fabric, whose latest release (3.2.3) pins invoke <3, so
  # nixpkgs marks fabric broken against invoke 3 (fabric/fabric#2376). Fabric's
  # main branch has the invoke 3 port, unreleased; this builds fabric from it,
  # the fix proposed upstream in NixOS/nixpkgs#576874. Of the code that ships,
  # the 13 commits past 3.2.3 change only connection.py and tasks.py (the port
  # itself), the version and the invoke pin. azure-cli's one use of fabric is
  # `az webapp ssh` (Connection(...).run(pty=True) in appservice/custom.py),
  # verified against a local sshd under azure-cli's own PYTHONPATH: the pty run
  # works and a failing command raises invoke's UnexpectedExit.
  #
  # A source pin, so the assert bounds its life: once nixpkgs stops marking
  # fabric broken (that PR, a fabric release, or NixOS/nixpkgs#576742 pinning
  # invoke 2 inside azure-cli's own package set), evaluation fails here instead
  # of silently pinning an old fabric. An extension rather than a top-level
  # override because fabric is a Python library: this reaches every Python
  # package set, azure-cli's private one included.
  pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
    (_: pyPrev: {
      fabric =
        assert prev.lib.assertMsg (pyPrev.fabric.meta.broken or false)
          "fabric override obsolete: nixpkgs no longer marks fabric ${pyPrev.fabric.version} broken. Delete the fabric override in overlays/default.nix.";
        pyPrev.fabric.overridePythonAttrs (old: {
          version = "3.2.3-unstable-2026-04-07";
          src = final.fetchFromGitHub {
            owner = "fabric";
            repo = "fabric";
            rev = "cc098ad475dbbe2e10aba72692d83aee58919570";
            hash = "sha256-Z1tGcjdLrzbqcbS6XwapSgDNpyLbBiO21yeqi7XhbpQ=";
          };
          # Every test in these two classes asserts on what a tunnel thread did
          # after a fixed 10-15 ms sleep, a race the suite's own comments
          # concede. Hydra's prebuilt fabric normally hides it; with this
          # override every host builds fabric itself, usually inside a parallel
          # switch. forward_local.distinct_remote_port failed here during a
          # parallel build and passed on an idle rebuild. The 13 commits leave
          # tests/ untouched.
          disabledTests = (old.disabledTests or [ ]) ++ [
            "forward_local"
            "forward_remote"
          ];
          meta = old.meta // {
            broken = false;
          };
        });
    })
  ];
}
