{
  lib,
  stdenvNoCC,
  fetchurl,
  unzip,
}:

# Nordwand Mono, a compact neo-grotesque monospace. Not in nixpkgs.
#
# Upstream commits no built fonts (fonts/* is gitignored); its release workflow
# generates them from the tag in CI and attaches one zip per format. The hash is
# the sha256 GitHub publishes for that asset (`gh release view --json assets`).
#
# TTF rather than OTF: the TTFs are ttfautohint-hinted while the OTFs carry no
# hints at all; glyph set, character map, advance widths and OpenType features
# are the same in both. CoreText ignores hinting, so macOS gives nothing up;
# FreeType, which renders on the Linux hosts, uses it at small sizes.
#
# GitHub labels the repo MIT from LICENSE.txt, but LICENSE-FONT.txt puts the
# font files under OFL-1.1.
stdenvNoCC.mkDerivation rec {
  pname = "nordwand-mono";
  version = "1.3.2";

  src = fetchurl {
    url = "https://github.com/tywr/Nordwand-Mono/releases/download/${version}/NordwandMono-TTF.zip";
    hash = "sha256-I1lRii5sdPUKiRJXMHcuaN5siHlR/0FOEbR+pSjOaoo=";
  };

  nativeBuildInputs = [ unzip ];

  # The zip is flat (built with `zip -j`): no top-level directory to enter.
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    install -Dm644 -t $out/share/fonts/truetype *.ttf
    runHook postInstall
  '';

  meta = {
    description = "Compact monospace neo-grotesque font designed for developers";
    homepage = "https://github.com/tywr/Nordwand-Mono";
    license = lib.licenses.ofl;
  };
}
