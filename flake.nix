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
    # Pinned to a nixpkgs rev compatible with raspberry-pi-nix.
    # Newer nixpkgs-unstable introduced images.nix which conflicts with rpi-nix's extlinux bootloader.
    nixpkgs-rpi.url = "github:NixOS/nixpkgs/cbd8ec4de4469333c82ff40d057350c30e9f7d36";

    # NixOS support for Raspberry Pi (kernel, firmware, board config).
    raspberry-pi-nix.url = "github:nix-community/raspberry-pi-nix";
    raspberry-pi-nix.inputs.nixpkgs.follows = "nixpkgs-rpi";

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
  outputs = { self, nixpkgs, nixpkgs-rpi, nix-darwin, disko, nixos-hardware, raspberry-pi-nix, termfilechooser, anker, claude-code-nix, nixvim, ... }:
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

      rpi5 = nixpkgs-rpi.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          # Provides the raspberry-pi-nix.board option and all RPi-specific config.
          raspberry-pi-nix.nixosModules.raspberry-pi
          raspberry-pi-nix.nixosModules.sd-image
          # Replace selected packages with current nixpkgs versions
          # (nixpkgs-rpi is pinned and ships outdated versions)
          { nixpkgs.overlays = [( final: prev: {
            gh = nixpkgs.legacyPackages.aarch64-linux.gh;
          })]; }
          ./hosts/rpi5/configuration.nix
        ];
      };

      aiagent = nixpkgs-rpi.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = {
          inherit anker claude-code-nix;
          # packages from current nixpkgs (nixpkgs-rpi versions are too old)
          whisper-cpp-pkg = nixpkgs.legacyPackages.aarch64-linux.whisper-cpp;
          tailscale-pkg = nixpkgs.legacyPackages.aarch64-linux.tailscale;
        };
        modules = [
          nixvim.nixosModules.nixvim
          raspberry-pi-nix.nixosModules.raspberry-pi
          raspberry-pi-nix.nixosModules.sd-image
          # Replace selected packages with current nixpkgs versions
          { nixpkgs.overlays = [( final: prev: {
            bat = nixpkgs.legacyPackages.aarch64-linux.bat;
            gh = nixpkgs.legacyPackages.aarch64-linux.gh;
            # nixvim.nix references top-level prettier which only exists in
            # the newer nixpkgs (nixpkgs-rpi still has it under nodePackages).
            prettier = nixpkgs.legacyPackages.aarch64-linux.prettier;
            # Pin k3s to unstable's version so aiagent's k3s-agent matches vps's k3s-server
            # (nixpkgs-rpi ships k3s 1.31, unstable ships 1.35+, gap breaks worker-server compatibility).
            k3s = nixpkgs.legacyPackages.aarch64-linux.k3s;
          })]; }
          ./hosts/aiagent/configuration.nix
        ];
      };
    };
  };
}
