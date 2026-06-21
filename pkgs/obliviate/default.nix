{
  lib,
  rustPlatform,
}:

rustPlatform.buildRustPackage {
  pname = "obliviate";
  version = "0.3.0";

  # Only the crate sources — never the local ./target build dir, which would
  # otherwise be copied into the store.
  src = lib.fileset.toSource {
    root = ../../bin/obliviate;
    fileset = lib.fileset.unions [
      ../../bin/obliviate/Cargo.toml
      ../../bin/obliviate/Cargo.lock
      ../../bin/obliviate/src
    ];
  };

  cargoLock.lockFile = ../../bin/obliviate/Cargo.lock;

  meta = {
    description = "Make Chrome forget a domain: erase its history, downloads, Journeys, and omnibox suggestions";
    mainProgram = "obliviate";
  };
}
