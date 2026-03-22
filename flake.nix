{
  description = "System configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-darwin = {
      url = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    # pinned to a nixpkgs rev compatible with raspberry-pi-nix
    # newer nixpkgs-unstable introduced images.nix which conflicts with rpi-nix's extlinux bootloader
    nixpkgs-rpi.url = "github:NixOS/nixpkgs/cbd8ec4de4469333c82ff40d057350c30e9f7d36";
    raspberry-pi-nix.url = "github:nix-community/raspberry-pi-nix";
    raspberry-pi-nix.inputs.nixpkgs.follows = "nixpkgs-rpi";
    termfilechooser.url = "github:charemma/xdg-desktop-portal-termfilechooser";
    termfilechooser.inputs.nixpkgs.follows = "nixpkgs";
    anker.url = "github:charemma/anker";
    anker.inputs.nixpkgs.follows = "nixpkgs";
    nix-openclaw.url = "github:openclaw/nix-openclaw";
    nix-openclaw.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nixpkgs-rpi, nix-darwin, disko, nixos-hardware, raspberry-pi-nix, termfilechooser, anker, nix-openclaw, ... }:
  let
    forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
    # openclaw-gateway built with current nixpkgs (needs fetchPnpmDeps, not in nixpkgs-rpi)
    openclawGateway = (nixpkgs.legacyPackages.aarch64-linux.extend nix-openclaw.overlays.default).openclaw-gateway;
  in {
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
    darwinConfigurations = {
      macbook = nix-darwin.lib.darwinSystem {
        system = "aarch64-darwin";
        specialArgs = { inherit anker; };
        modules = [
          ./hosts/macbook/configuration.nix
        ];
      };
    };

    nixosConfigurations = {
      north = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit termfilechooser anker; };
        modules = [
          ./hosts/north/configuration.nix
        ];
      };

      vps = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          ./hosts/vps/configuration.nix
        ];
      };

      rpi5 = nixpkgs-rpi.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
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
