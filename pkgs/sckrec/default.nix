{
  lib,
  stdenv,
  swift,
  darwinMinVersionHook,
}:

stdenv.mkDerivation {
  pname = "sckrec";
  version = "0.1.0";

  src = lib.fileset.toSource {
    root = ../../bin/sckrec;
    fileset = lib.fileset.unions [
      ../../bin/sckrec/sckrec.swift
      ../../bin/sckrec/Info.plist
    ];
  };

  # The CoreAudio process-tap API (CATapDescription, kAudioTapPropertyFormat)
  # needs SDK 14.2+ and ScreenCaptureKit needs 12.3+. Swift's own SDK (14.4)
  # carries both, so only the deployment target has to move; it defaults to
  # 14.0, which the availability checker rejects.
  #
  # Do not reach for a newer apple-sdk to get there. Adding one points -sdk at
  # the new headers while the toolchain's own .swiftinterface files still
  # resolve against 14.4, and the ClangImporter then cannot build
  # _Builtin_intrinsics from the newer arm_neon.h. It retries against the
  # module cache instead of failing, so the build hangs for hours.
  nativeBuildInputs = [ swift ];
  buildInputs = [ (darwinMinVersionHook "14.2") ];

  buildPhase = ''
    runHook preBuild
    # The embedded Info.plist names the binary for the macOS privacy
    # indicator; without it captures are attributed to "unknown".
    swiftc -O -o sckrec sckrec.swift \
      -Xlinker -sectcreate -Xlinker __TEXT -Xlinker __info_plist -Xlinker Info.plist
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 sckrec $out/bin/sckrec
    runHook postInstall
  '';

  meta = {
    description = "Screen plus system audio recorder for macOS, no loopback driver required";
    mainProgram = "sckrec";
    platforms = lib.platforms.darwin;
  };
}
