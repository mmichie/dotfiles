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
      crane,
    }:
    let
      # Overlay: exposes pkgs.stable.* for pinning packages to the stable channel
      # Usage in modules: pkgs.stable.ansible (if unstable breaks it, etc.)
      stableOverlay = system: final: prev: {
        stable = nixpkgs-stable.legacyPackages.${system};
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
          plx = plx.packages.aarch64-darwin.default;
        };
        modules = [
          { nixpkgs.overlays = [ (stableOverlay "aarch64-darwin") ]; }
          ./hosts/mims-mbp/configuration.nix
          home-manager.darwinModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "backup";
              extraSpecialArgs = {
                inherit self;
                plx = plx.packages.aarch64-darwin.default;
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
          plx = plx.packages.aarch64-linux.default;
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
                plx = plx.packages.aarch64-linux.default;
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
          config.allowUnfree = true;
          overlays = [ (stableOverlay "x86_64-linux") ];
        };
        extraSpecialArgs = {
          inherit self;
          plx = plx.packages.x86_64-linux.default;
        };
        modules = sharedHomeModules ++ [ ./home/linux.nix ];
      };

      # ── Formatter ────────────────────────────────────────────────────
      formatter = {
        aarch64-darwin = nixpkgs.legacyPackages.aarch64-darwin.nixfmt-tree;
        aarch64-linux = nixpkgs.legacyPackages.aarch64-linux.nixfmt-tree;
        x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;
      };
    };
}
