# macbook -- Apple M-series laptop (aarch64-darwin, managed via nix-darwin)
#
# nix-darwin mirrors the NixOS module system but targets macOS.
# Not all NixOS options are available -- darwin has its own equivalents.
{ config, lib, pkgs, ... }:

{
  imports = [
    ../../modules/core.nix
    ../../modules/dev.nix
    ../../modules/binary-cache.nix
  ];

  networking.hostName = "macbook";

  time.timeZone = "Europe/Athens";

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "charemma" ];
    builders-use-substitutes = true;
  };
  # Allow packages with non-free licenses.
  nixpkgs.config.allowUnfree = true;

  # Starts a Linux VM in the background that acts as a remote builder.
  # Allows building x86_64-linux and aarch64-linux derivations from macOS.
  nix.linux-builder.enable = true;

  # Allow sudo via Touch ID instead of typing a password.
  # sudo_local is the PAM service used by the terminal sudo on macOS.
  security.pam.services.sudo_local.touchIdAuth = true;

  environment.systemPackages = with pkgs; [
    qemu  # run NixOS VMs locally for testing
  ];

  # The version of nix-darwin this config was first set up with.
  # Integer format (6) instead of the NixOS string format ("26.05").
  system.stateVersion = 6;
}
