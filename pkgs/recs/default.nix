{
  perlPackages,
  fetchurl,
}:

perlPackages.buildPerlPackage {
  pname = "App-RecordStream";
  version = "4.0.25";

  src = fetchurl {
    url = "mirror://cpan/authors/id/T/TS/TSIBLEY/App-RecordStream-4.0.25.tar.gz";
    hash = "sha256-B/qWMdLfQXqZE163F/96MeFMRrDpuO8fWiD4Z5ditMs=";
  };

  propagatedBuildInputs = with perlPackages; [
    JSONMaybeXS
    TextCSV
    DateManip
    TextAutoformat
    ModulePluggable
    IOString
    PodPerldoc
  ];

  nativeCheckInputs = [ perlPackages.ModuleVersionsReport ];

  meta = {
    description = "Command-line analysis tools for record-oriented data";
    mainProgram = "recs";
  };
}
