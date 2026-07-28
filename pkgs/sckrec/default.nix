{
  lib,
  stdenv,
  swift,
  apple-sdk_26,
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

  nativeBuildInputs = [ swift ];

  # The CoreAudio process-tap API (CATapDescription, kAudioTapPropertyFormat)
  # only exists in SDK 14.2+, and ScreenCaptureKit needs 12.3+; the SDK the
  # nixpkgs swift wrapper defaults to predates both. Raise the deployment
  # target to match, or swiftc's availability checker rejects the calls.
  buildInputs = [ apple-sdk_26 ];
  env.MACOSX_DEPLOYMENT_TARGET = "15.0";

  buildPhase = ''
    runHook preBuild
    # The embedded Info.plist names the binary for the macOS privacy
    # indicator; without it captures are attributed to "unknown".
    swiftc -O -sdk "$SDKROOT" -o sckrec sckrec.swift \
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
