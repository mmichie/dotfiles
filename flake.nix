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

    crane.url = "github:ipetkov/crane";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-stable,
      nix-darwin,
      home-manager,
      crane,
    }:
    let
      # Overlay: exposes pkgs.stable.* for pinning packages to the stable channel
      # Usage in modules: pkgs.stable.ansible (if unstable breaks it, etc.)
      stableOverlay = system: final: prev: {
        stable = nixpkgs-stable.legacyPackages.${system};
      };

      # Helper to build starship-segments for a given system
      starshipSegmentsFor =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          craneLib = crane.mkLib pkgs;
        in
        craneLib.buildPackage {
          src = craneLib.cleanCargoSource ./starship-segments;
          strictDeps = true;
          nativeBuildInputs = [
            pkgs.pkg-config
            pkgs.cmake
          ];
          buildInputs = [
            pkgs.openssl
          ]
          ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
            pkgs.apple-sdk_15
            pkgs.libiconv
          ];
        };

      # Shared home-manager modules used by both darwin and linux
      sharedHomeModules = [
        ./home/shared.nix
        ./modules/home/packages.nix
        ./modules/home/shell.nix
        ./modules/home/git.nix
        ./modules/home/editor.nix
        ./modules/home/terminal.nix
      ];
    in
    {
      # ── macOS (nix-darwin with embedded home-manager) ──────────────
      darwinConfigurations."mims-mbp" = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = {
          inherit self;
          starship-segments = starshipSegmentsFor "aarch64-darwin";
        };
        modules = [
          { nixpkgs.overlays = [ (stableOverlay "aarch64-darwin") ]; }
          ./hosts/mims-mbp/configuration.nix
          home-manager.darwinModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = {
                inherit self;
                starship-segments = starshipSegmentsFor "aarch64-darwin";
              };
              users.mim = {
                imports = sharedHomeModules ++ [ ./hosts/mims-mbp/home.nix ];
              };
            };
          }
        ];
      };

      # ── NixOS VM (VMware Fusion on Apple Silicon) ─────────────────
      nixosConfigurations."vm-aarch64" = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = {
          inherit self;
          starship-segments = starshipSegmentsFor "aarch64-linux";
        };
        modules = [
          { nixpkgs.overlays = [ (stableOverlay "aarch64-linux") ]; }
          ./hosts/vm-aarch64/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = {
                inherit self;
                starship-segments = starshipSegmentsFor "aarch64-linux";
              };
              users.mim = {
                imports = sharedHomeModules ++ [ ./hosts/vm-aarch64/home.nix ];
              };
            };
          }
        ];
      };

      # ── Linux (standalone home-manager) ────────────────────────────
      homeConfigurations."mim@linux" = home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          system = "x86_64-linux";
          overlays = [ (stableOverlay "x86_64-linux") ];
        };
        extraSpecialArgs = {
          inherit self;
          starship-segments = starshipSegmentsFor "x86_64-linux";
        };
        modules = sharedHomeModules ++ [ ./home/linux.nix ];
      };

      # ── Packages ───────────────────────────────────────────────────
      packages = {
        aarch64-darwin.starship-segments = starshipSegmentsFor "aarch64-darwin";
        aarch64-linux.starship-segments = starshipSegmentsFor "aarch64-linux";
        x86_64-linux.starship-segments = starshipSegmentsFor "x86_64-linux";
      };

      # ── Formatter ────────────────────────────────────────────────────
      formatter = {
        aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt-tree;
        aarch64-linux = nixpkgs.legacyPackages.aarch64-linux.nixfmt-tree;
        x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;
      };
    };
}
