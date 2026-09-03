{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

# Mutation testing for Go: generates mutants from the AST, runs the covering
# tests against each, and reports the ones that SURVIVE — a survivor is a change
# to the code that no test noticed.
#
# Not in nixpkgs. Packaged here rather than `go install`ed so it is pinned and
# reproducible like everything else on this machine.
#
# Chosen over zimmski/go-mutesting on maintenance: go-mutesting's last commit is
# 2021-06-10, five years dormant. gremlins was last pushed 2026-06-26 with
# commits into 2026-03. The Go mutation-testing ecosystem is thin enough that
# this mattered — it was the deciding factor, not a preference.
#
# v0.6.0 is the newest RELEASE (2025-12-06); there is unreleased work on main.
# Pin the tag rather than a commit so bumps are deliberate.
buildGoModule rec {
  pname = "gremlins";
  version = "0.6.0";

  src = fetchFromGitHub {
    owner = "go-gremlins";
    repo = "gremlins";
    tag = "v${version}";
    hash = "sha256-QwMj7aA4eafMT25gBLAomZMliCbueoEsDHD/nxtnmk4=";
  };

  vendorHash = "sha256-TYbbDN2V6GLj+YRNQIKggCnNspk3M96cP1DSe8P9qlY=";

  subPackages = [ "cmd/gremlins" ];

  ldflags = [
    "-s"
    "-w"
    "-X main.version=${version}"
  ];

  # The upstream suite shells out to `go test` against fixture modules, which
  # needs a writable GOCACHE and network-free module resolution the sandbox does
  # not provide. The binary is what this package exists for; upstream CI owns the
  # tests.
  doCheck = false;

  meta = {
    description = "Mutation testing tool for Go";
    homepage = "https://github.com/go-gremlins/gremlins";
    license = lib.licenses.asl20;
    mainProgram = "gremlins";
  };
}
