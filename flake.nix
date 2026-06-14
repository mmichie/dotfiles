{
  description = "mim's dotfiles — nix-darwin + home-manager";

  # Include vendored submodules (tmux plugins) in the flake source so
  # checks.* can exercise the real tmux config, tpm included.
  inputs.self.submodules = true;

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

    chevron = {
      # Track the unstable branch so this dotfiles checkout exercises
      # in-flight chevron work continuously. Pin to a tag
      # (github:shiprock/chevron/v0.6.0) on machines that need a known
      # quiet build.
      url = "github:shiprock/chevron/unstable";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-stable,
      nix-darwin,
      home-manager,
      chevron,
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
          chevron
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

      # ── Packages ──────────────────────────────────────────────────
      # Surface the repo's custom package as a first-class flake output
      # (`nix build .#recs`, `nix run .#recs`). recs is also injected into
      # every host via the custom-packages overlay below; this is the same
      # derivation, just reachable directly.
      packages = forAllSystems (pkgs: {
        recs = pkgs.callPackage ./pkgs/recs { };
      });

      # ── Overlays ──────────────────────────────────────────────────
      # The custom-packages overlay (recs + rclone/pipx fixups) that every
      # host applies, re-exported so other flakes can pull it in via
      # `inputs.dotfiles.overlays.default`.
      overlays.default = import ./overlays;

      # ── Formatter ─────────────────────────────────────────────────
      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);

      # ── Checks ────────────────────────────────────────────────────
      # Hermetic config test suite (tests/run.zsh) — zsh modules + tmux
      # config on isolated server sockets. Same suite as `just test`, the
      # lefthook pre-commit hook, and the CI job.
      checks = forAllSystems (pkgs: {
        zsh-config =
          pkgs.runCommand "zsh-config-tests"
            {
              nativeBuildInputs = [
                pkgs.zsh
                pkgs.tmux
              ];
            }
            ''
              cd ${self}
              # nixpkgs zsh compiles its global rc dir into the store, and
              # that zshenv is ALWAYS sourced (--no-globalrcs only skips
              # zprofile/zshrc/zlogin). On non-NixOS it chains to the HOST's
              # /etc/zshenv — visible in the relaxed darwin sandbox — whose
              # set-environment replaces PATH with the system profile
              # template, silently swapping pinned store inputs for host
              # tools. Both set-environment scripts honor a guard:
              export __NIX_DARWIN_SET_ENVIRONMENT_DONE=1
              export __NIXOS_SET_ENVIRONMENT_DONE=1
              zsh --no-globalrcs tests/run.zsh
              touch $out
            '';
      });

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
            pkgs.gitleaks
            pkgs.lefthook
            pkgs.just
            pkgs.gh
            pkgs.zsh
            pkgs.tmux
            pkgs.neovim # tests/test_nvim.zsh parse tier in CI
          ];
        };
      });
    };
}
