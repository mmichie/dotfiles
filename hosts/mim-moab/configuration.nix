{
  imports = [ ../../modules/darwin/workstation-base.nix ];
  networking.hostName = "mim-moab";

  # Kept on Homebrew because pyenv's plugin model and Python C-ext build
  # flags need /opt/homebrew layout.
  homebrew.brews = [
    "pyenv"
    "pyenv-virtualenv"
    "libmemcached"
    "graphviz"
    "postgresql"
  ];
}
