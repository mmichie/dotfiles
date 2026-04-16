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
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-stable,
      nix-darwin,
      home-manager,
      plx,
      ...
    }:
    let
      mkHost = import ./lib/mkHost.nix {
        inherit
          self
          nixpkgs
          nixpkgs-stable
          nix-darwin
          home-manager
          plx
          ;
      };
      inherit (mkHost) mkDarwinHost mkNixosHost mkHomeConfig;
    in
    {
      # ── macOS (nix-darwin with embedded home-manager) ──────────────
      darwinConfigurations = {
        "mims-mbp" = mkDarwinHost { hostname = "mims-mbp"; };

        "moab-mbp" = mkDarwinHost {
          hostname = "moab-mbp";
          extraHomeModules = [ { my.isWork = true; } ];
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
        extraHomeModules = [ ./hosts/vm-aarch64/home.nix ];
      };

      # ── Linux (standalone home-manager) ───────────────────────────
      homeConfigurations."mim@linux" = mkHomeConfig {
        system = "x86_64-linux";
        extraHomeModules = [ ./home/linux.nix ];
      };

      # ── Formatter ─────────────────────────────────────────────────
      formatter = {
        aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt-tree;
        aarch64-linux = nixpkgs.legacyPackages.aarch64-linux.nixfmt-tree;
        x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;
      };
    };
}
