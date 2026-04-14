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
  stableOverlay = system: final: prev: {
    stable = nixpkgs-stable.legacyPackages.${system};
  };

  plxOverlay = system: final: prev: {
    plx = plx.packages.${system}.default;
  };

  overlays = system: [
    (stableOverlay system)
    (plxOverlay system)
  ];

  # Pin nix registry to flake inputs so `nix run nixpkgs#foo` uses flake.lock.
  # Uses home-manager's nix.registry (user-level ~/.config/nix/registry.json)
  # because macOS nix.enable = false skips system-level registry activation.
  flakeInputs = nixpkgs.lib.filterAttrs (_: nixpkgs.lib.isType "flake") {
    inherit
      nixpkgs
      nixpkgs-stable
      nix-darwin
      home-manager
      plx
      ;
  };
  registryHomeModule = {
    nix.registry = nixpkgs.lib.mapAttrs (_: flake: { inherit flake; }) flakeInputs;
  };

  # ── Home module sets ─────────────────────────────────────────────────

  # Shared across all classes
  coreHomeModules = [
    ../modules/home/options.nix
    ../home/shared.nix
    ../modules/home/packages-core.nix
    ../modules/home/shell.nix
    ../modules/home/git.nix
    ../modules/home/editor.nix
    ../modules/home/terminal.nix
  ];

  # Additional modules for workstation classes (macOS + Linux)
  workstationHomeModules = [
    ../modules/home/packages-dev.nix
  ];

  # ── Class definitions ────────────────────────────────────────────────

  classConfig = {
    darwin-workstation = {
      homeModules = coreHomeModules ++ workstationHomeModules;
      homeBase = ../hostclass/darwin-workstation.nix;
    };
    linux-workstation = {
      homeModules = coreHomeModules ++ workstationHomeModules;
      homeBase = ../hostclass/linux-workstation.nix;
    };
  };

  # ── Host constructors ────────────────────────────────────────────────

  mkDarwinHost =
    {
      hostname,
      username ? "mim",
      system ? "aarch64-darwin",
      class ? "darwin-workstation",
      extraHomeModules ? [ ],
    }:
    let
      cc = classConfig.${class};
    in
    nix-darwin.lib.darwinSystem {
      inherit system;
      specialArgs = { inherit self username; };
      modules = [
        ../hosts/${hostname}/configuration.nix
        home-manager.darwinModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "backup";
            users.${username} = {
              imports =
                cc.homeModules
                ++ [
                  cc.homeBase
                  registryHomeModule
                ]
                ++ extraHomeModules;
              my.user.name = username;
            };
          };
        }
        { nixpkgs.overlays = overlays system; }
      ];
    };

  mkNixosHost =
    {
      hostname,
      username ? "mim",
      system ? "aarch64-linux",
      class ? "linux-workstation",
      extraModules ? [ ],
      extraHomeModules ? [ ],
    }:
    let
      cc = classConfig.${class};
    in
    nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = { inherit self username; };
      modules = [
        ../hosts/${hostname}/configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            users.${username} = {
              imports =
                cc.homeModules
                ++ [
                  cc.homeBase
                  registryHomeModule
                ]
                ++ extraHomeModules;
              my.user.name = username;
            };
          };
        }
        { nixpkgs.overlays = overlays system; }
      ]
      ++ extraModules;
    };

  mkHomeConfig =
    {
      username ? "mim",
      system ? "x86_64-linux",
      class ? "linux-workstation",
      extraHomeModules ? [ ],
    }:
    let
      cc = classConfig.${class};
    in
    home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = overlays system;
      };
      modules =
        cc.homeModules
        ++ [
          cc.homeBase
          registryHomeModule
        ]
        ++ extraHomeModules
        ++ [
          { my.user.name = username; }
        ];
    };

in
{
  inherit mkDarwinHost mkNixosHost mkHomeConfig;
}
