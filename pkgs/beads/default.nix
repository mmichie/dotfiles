{
  buildGoModule,
  fetchFromGitHub,
  go_1_26,
  icu,
  git,
  pkg-config,
}:

(buildGoModule.override { go = go_1_26; }) rec {
  pname = "beads";
  version = "0.55.4";

  src = fetchFromGitHub {
    owner = "steveyegge";
    repo = "beads";
    rev = "v${version}";
    hash = "sha256-HTcmGKn2NNoBEg5yRsnVIATNdte5Xw8E86D09e1X5nk=";
  };

  vendorHash = "sha256-cMvxGJBMUszIbWwBNmWe+ws4m3mfyEZgapxVYNYc5c4=";
  subPackages = [ "cmd/bd" ];
  doCheck = false;
  env.CGO_ENABLED = "1";
  buildInputs = [ icu ];
  nativeBuildInputs = [
    git
    pkg-config
  ];

  meta = {
    description = "Distributed issue tracker for AI-supervised workflows";
    mainProgram = "bd";
  };
}
