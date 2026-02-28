{
  description = "NixOS configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    charemma-web = {
      url = "github:charemma/charemma-web";
      flake = false;
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    raspberry-pi-nix.url = "github:nix-community/raspberry-pi-nix";
  };

  outputs = { self, nixpkgs, disko, charemma-web, nixos-hardware, raspberry-pi-nix, ... }: {
    nixosConfigurations = {
      north = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          ./hosts/north/configuration.nix
        ];
      };

      framework = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          nixos-hardware.nixosModules.framework-12-13th-gen-intel
          ./hosts/framework/configuration.nix
        ];
      };

      vps = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit charemma-web; };
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
    };
  };
}
