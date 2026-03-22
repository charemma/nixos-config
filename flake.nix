{
  description = "System configurations";

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

    # NixOS support for Raspberry Pi (kernel, firmware, board config).
    # Pinned to a nixpkgs rev compatible with raspberry-pi-nix:
    # newer nixpkgs-unstable introduced images.nix which conflicts with rpi-nix's extlinux bootloader.
    nixpkgs-rpi.url = "github:NixOS/nixpkgs/cbd8ec4de4469333c82ff40d057350c30e9f7d36";
    raspberry-pi-nix.url = "github:nix-community/raspberry-pi-nix";
    raspberry-pi-nix.inputs.nixpkgs.follows = "nixpkgs-rpi";

    # Personal fork of the xdg-desktop-portal-termfilechooser portal.
    termfilechooser.url = "github:charemma/xdg-desktop-portal-termfilechooser";
    termfilechooser.inputs.nixpkgs.follows = "nixpkgs";

    # Workday recap CLI tool (personal project).
    anker.url = "github:charemma/anker";
    anker.inputs.nixpkgs.follows = "nixpkgs";
    nix-openclaw.url = "github:openclaw/nix-openclaw";
    nix-openclaw.inputs.nixpkgs.follows = "nixpkgs";
  };

  # outputs is a function that receives all inputs and returns an attribute set.
  # The `self` argument refers to this flake itself (useful for referencing its own outputs).
  outputs = { self, nixpkgs, nixpkgs-rpi, nix-darwin, disko, nixos-hardware, raspberry-pi-nix, termfilechooser, anker, nix-openclaw, ... }:
  let
    # Helper to produce one attribute per supported system without repeating the list.
    # Used for devShells which need to work on all platforms.
    forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
    # openclaw-gateway built with current nixpkgs (needs fetchPnpmDeps, not in nixpkgs-rpi)
    openclawGateway = (nixpkgs.legacyPackages.aarch64-linux.extend nix-openclaw.overlays.default).openclaw-gateway;
  in {
    # A development shell with tools for managing infra (Pulumi, kubectl).
    # Enter with `nix develop` in this repo.
    devShells = forAllSystems (system: let
      pkgs = nixpkgs.legacyPackages.${system};
    in {
      default = pkgs.mkShell {
        packages = with pkgs; [
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
        specialArgs = { inherit anker; };
        modules = [
          ./hosts/macbook/configuration.nix
        ];
      };
    };

    # NixOS configurations (Linux hosts).
    nixosConfigurations = {
      north = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        # Both termfilechooser and anker are flake inputs that modules need directly.
        # inherit is shorthand for termfilechooser = termfilechooser; anker = anker;
        specialArgs = { inherit termfilechooser anker; };
        modules = [
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

      rpi5 = nixpkgs-rpi.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          # Provides the raspberry-pi-nix.board option and all RPi-specific config.
          raspberry-pi-nix.nixosModules.raspberry-pi
          raspberry-pi-nix.nixosModules.sd-image
          ./hosts/rpi5/configuration.nix
        ];
      };

      aiagent = nixpkgs-rpi.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          raspberry-pi-nix.nixosModules.raspberry-pi
          raspberry-pi-nix.nixosModules.sd-image
          nix-openclaw.nixosModules.openclaw-gateway
          # use openclaw built with current nixpkgs -- nixpkgs-rpi is too old for fetchPnpmDeps
          { services.openclaw-gateway.package = openclawGateway; }
          ./hosts/aiagent/configuration.nix
        ];
      };
    };
  };
}
