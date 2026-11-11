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

  # pre-commit's test suite exercises its .NET hook support, so nixpkgs puts
  # the source-built .NET 8 SDK (dotnetCorePackages.sdk_8_0-source) in its
  # check inputs and DOTNET_ROOT. Usually cache.nixos.org serves a prebuilt
  # pre-commit and those tests never run here. It had no aarch64-darwin build
  # for nixpkgs 4fe25e1, and the local build compiled .NET from source twice
  # (stage0, then the final VMR): hours, for a test-only dependency the
  # installed pre-commit never references. Without its tests and the env they
  # set, pre-commit has no .NET in its build closure and builds in seconds.
  # doCheck = false alone still ran pytest, and failed for want of the test
  # inputs it had dropped: identify propagates pytestCheckHook, which queues
  # its phase whenever it is present, so dontUsePytestCheck switches it off.
  # Darwin only: Linux hosts keep the cached, tested build.
  pre-commit =
    if prev.stdenv.hostPlatform.isDarwin then
      prev.pre-commit.overridePythonAttrs (old: {
        doCheck = false;
        dontUsePytestCheck = true;
        env = builtins.removeAttrs (old.env or { }) [
          "DOTNET_ROOT"
          "NuGetAudit"
        ];
      })
    else
      prev.pre-commit;
}
