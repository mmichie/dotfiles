{
  description = "mim's dotfiles — nix-darwin + home-manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";

    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    plx = {
      url = "github:mmichie/plx";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.crane.follows = "crane";
    };

    crane.url = "github:ipetkov/crane";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      nixpkgs-stable,
      nix-darwin,
      home-manager,
      plx,
      sops-nix,
      ...
    }:
    let
      mkHost = import ./lib/mkHost.nix {
        inherit
          nixpkgs
          nixpkgs-stable
          nix-darwin
          home-manager
          plx
          sops-nix
          ;
      };
      inherit (mkHost) mkDarwinHost mkNixosHost mkHomeConfig;

      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      # ── macOS (nix-darwin with embedded home-manager) ──────────────
      darwinConfigurations = {
        "mims-mbp" = mkDarwinHost { hostname = "mims-mbp"; };

        "mim-moab" = mkDarwinHost {
          hostname = "mim-moab";
          extraHomeModules = [
            { my.isWork = true; }
            ./hosts/mim-moab/home.nix
          ];
        };

        "tensor9-mbp" = mkDarwinHost {
          hostname = "tensor9-mbp";
          extraHomeModules = [ { my.isWork = true; } ];
        };
      };

      # ── NixOS VM (VMware Fusion on Apple Silicon) ─────────────────
      nixosConfigurations."vm-aarch64" = mkNixosHost {
        hostname = "vm-aarch64";
        system = "aarch64-linux";
      };

      # ── Linux (standalone home-manager) ───────────────────────────
      homeConfigurations."mim@linux" = mkHomeConfig {
        system = "x86_64-linux";
      };

      # ── Formatter ─────────────────────────────────────────────────
      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);

      # ── Dev shell ─────────────────────────────────────────────────
      # Matches the tools invoked by lefthook.yml so `nix develop` gives
      # contributors (and CI) the same environment the pre-commit hooks use.
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShellNoCC {
          packages = [
            pkgs.nixfmt-tree
            pkgs.statix
            pkgs.shellcheck
            pkgs.shfmt
            pkgs.lefthook
            pkgs.just
            pkgs.gh
          ];
        };
      });
    };
}
