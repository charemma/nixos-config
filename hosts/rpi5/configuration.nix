{ config, lib, pkgs, ... }:

{
  imports = [
    ../../modules/core.nix
    ../../modules/remote-access.nix
    ../../modules/binary-cache.nix
    ../../modules/users.nix
  ];

  charemma.extraGroups = [ "networkmanager" ];

  raspberry-pi-nix.board = "bcm2712";

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };

  networking.hostName = "rpi5";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Athens";
  i18n.defaultLocale = "en_US.UTF-8";

  programs.zsh.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "26.05";
}
