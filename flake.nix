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
    raspberry-pi-nix.url = "github:nix-community/raspberry-pi-nix";
    termfilechooser.url = "github:charemma/xdg-desktop-portal-termfilechooser";
    termfilechooser.inputs.nixpkgs.follows = "nixpkgs";
    anker.url = "github:charemma/anker";
    anker.inputs.nixpkgs.follows = "nixpkgs";
    nix-openclaw.url = "github:openclaw/nix-openclaw";
    nix-openclaw.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, nix-darwin, disko, nixos-hardware, raspberry-pi-nix, termfilechooser, anker, nix-openclaw, ... }:
  let
    forAllSystems = nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" ];
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

      rpi5 = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          raspberry-pi-nix.nixosModules.raspberry-pi
          ./hosts/rpi5/configuration.nix
        ];
      };

      aiagent = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          raspberry-pi-nix.nixosModules.raspberry-pi
          nix-openclaw.nixosModules.openclaw-gateway
          { nixpkgs.overlays = [ nix-openclaw.overlays.default ]; }
          ./hosts/aiagent/configuration.nix
        ];
      };
    };
  };
}
