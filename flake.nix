{
  description = "System configurations";

  # Binary cache for the RPi5 kernel/firmware bundles from nixos-raspberrypi,
  # so we do not build them from scratch.
  nixConfig = {
    extra-substituters = [ "https://nixos-raspberrypi.cachix.org" ];
    extra-trusted-public-keys = [
      "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
    ];
  };

  inputs = {
    # The main nixpkgs channel. unstable means rolling releases, not unstable software.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # nix-darwin brings the NixOS module system to macOS.
    # inputs.nixpkgs.follows = "nixpkgs" means nix-darwin reuses our nixpkgs
    # instead of pulling its own, keeping the package set consistent.
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # disko: declarative disk partitioning, used during nixos-anywhere installs.
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # Hardware-specific NixOS modules (kernel params, drivers) for common devices.
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    # Actively maintained RPi5 support with matched kernel+firmware bundles and a
    # binary cache, tracking current nixpkgs.
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";

    # Personal fork of the xdg-desktop-portal-termfilechooser portal.
    termfilechooser.url = "github:charemma/xdg-desktop-portal-termfilechooser";
    termfilechooser.inputs.nixpkgs.follows = "nixpkgs";

    # Workday recap CLI tool (personal project).
    anker.url = "github:charemma/anker";
    anker.inputs.nixpkgs.follows = "nixpkgs";
    claude-code-nix.url = "github:sadjow/claude-code-nix";
    claude-code-nix.inputs.nixpkgs.follows = "nixpkgs";

    # NixVim: declarative neovim configuration via Nix modules.
    nixvim.url = "github:nix-community/nixvim";
  };

  # outputs is a function that receives all inputs and returns an attribute set.
  # The `self` argument refers to this flake itself (useful for referencing its own outputs).
  outputs = { self, nixpkgs, nix-darwin, disko, nixos-hardware, nixos-raspberrypi, termfilechooser, anker, claude-code-nix, nixvim, ... }:
  let
    # Helper to produce one attribute per supported system without repeating the list.
    # Used for devShells which need to work on all platforms.
    forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
  in {
    # A development shell with tools for managing infra (Pulumi, kubectl).
    # Enter with `nix develop` in this repo.
    devShells = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.mkShell {
        packages = with pkgs; [
          just
          kubectl
          nodejs
          pulumi
          pulumiPackages.pulumi-language-nodejs
        ];
      };
    });

    # nix-darwin configurations (macOS hosts).
    # specialArgs passes extra values into modules that need flake inputs beyond nixpkgs.
    darwinConfigurations = {
      macbook = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = { inherit anker claude-code-nix; };
        modules = [
          ./hosts/macbook/configuration.nix
        ];
      };
    };

    # NixOS configurations (Linux hosts).
    nixosConfigurations = {
      north = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        # Flake inputs that modules need directly.
        # inherit is shorthand for termfilechooser = termfilechooser; anker = anker;
        specialArgs = { inherit termfilechooser anker claude-code-nix; };
        modules = [
          nixvim.nixosModules.nixvim
          ./hosts/north/configuration.nix
        ];
      };

      vps = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          # Import the disko NixOS module so disko.devices options become available.
          disko.nixosModules.disko
          ./hosts/vps/configuration.nix
        ];
      };


      # aiagent runs current nixpkgs via nixos-raspberrypi (matched RPi5
      # kernel+firmware). k3s stays pinned to the nixpkgs input so the agent
      # matches vps's k3s-server version.
      aiagent = nixos-raspberrypi.lib.nixosSystem {
        specialArgs = {
          inherit anker claude-code-nix;
          whisper-cpp-pkg = nixpkgs.legacyPackages.aarch64-linux.whisper-cpp;
        };
        modules = [
          {
            imports = with nixos-raspberrypi.nixosModules; [
              raspberry-pi-5.base
              raspberry-pi-5.display-vc4
              # Provides config.system.build.sdImage with the RPi kernel
              # bootloader (not generic-extlinux). Required to build the
              # flashable SD image; without it the generic nixpkgs sd-card
              # image conflicts on system.build.installBootLoader.
              sd-image
            ];
          }
          nixvim.nixosModules.nixvim
          { nixpkgs.overlays = [( final: prev: {
            k3s = nixpkgs.legacyPackages.aarch64-linux.k3s;
          })]; }
          ./hosts/aiagent/configuration.nix
        ];
      };
    };
  };
}
