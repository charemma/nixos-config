{ config, lib, pkgs, ... }:

{
  imports = [
    ../../modules/dev.nix
  ];

  networking.hostName = "macbook";

  time.timeZone = "Europe/Athens";

  # Nix
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "charemma" ];
  };
  nixpkgs.config.allowUnfree = true;

  # Linux builder VM for cross-platform Nix builds (x86_64-linux, aarch64-linux)
  nix.linux-builder.enable = true;

  # Security
  security.pam.services.sudo_local.touchIdAuth = true;

  environment.systemPackages = with pkgs; [
    vim
    qemu
  ];

  system.stateVersion = 6;
}
