# rpi5 -- Raspberry Pi 5 (aarch64-linux)
#
# NixOS modules are functions: the module system injects arguments like pkgs, lib, config.
# `...` ignores any extra arguments we don't need here.
{ config, lib, pkgs, ... }:

{
  # imports merges other module files into this configuration.
  # The module system collects all option assignments across all imported files
  # and evaluates them together -- order does not matter.
  imports = [
    ../../modules/core.nix
    ../../modules/remote-access.nix
    ../../modules/binary-cache.nix
    ../../modules/users.nix
  ];

  # Option declared in modules/users.nix -- adds networkmanager to the user's groups.
  charemma.extraGroups = [ "networkmanager" ];

  # Board identifier for the raspberry-pi-nix flake input.
  # bcm2712 is the chip in the RPi 5. The flake uses this to select the right kernel and firmware.
  raspberry-pi-nix.board = "bcm2712";

  # The SD card image is partitioned with a label NIXOS_SD.
  # by-label is more stable than by device path (e.g. /dev/sda) which can change.
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };

  networking.hostName = "rpi5";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Athens";
  i18n.defaultLocale = "en_US.UTF-8";

  # zsh must be enabled system-wide here so it is listed in /etc/shells,
  # which is required for it to be a valid login shell for the charemma user.
  programs.zsh.enable = true;

  nix.settings = {
    # nix-command and flakes are still experimental and must be explicitly opted in.
    experimental-features = [ "nix-command" "flakes" ];
    # trusted-users can modify nix.conf settings at runtime (e.g. add substituters).
    trusted-users = [ "charemma" ];
  };

  # Declares which NixOS release this system was first installed with.
  # Controls backwards-compatibility behaviour for stateful services.
  # Do not change after initial install.
  system.stateVersion = "26.05";
}
