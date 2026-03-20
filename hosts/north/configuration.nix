{ config, lib, pkgs, ... }:

{
  imports =
    [ ./hardware-configuration.nix
      ../../modules/desktop.nix
      ../../modules/core.nix
      ../../modules/dev.nix
      ../../modules/remote-desktop.nix
      ../../modules/infosec.nix
      ../../modules/binary-cache.nix
      ../../modules/vm-bridge.nix
      ../../modules/users.nix
    ];

  charemma.extraGroups = [ "networkmanager" "video" "audio" ];

  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.efi.efiSysMountPoint = "/boot/efi";

  networking.hostName = "north";
  networking.networkmanager.enable = true;

  time.timeZone = "Europe/Athens";
  i18n.defaultLocale = "en_US.UTF-8";

  # Sound
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  programs.zsh.enable = true;
  programs.nix-ld.enable = true;

  hardware.graphics.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.trusted-users = [ "charemma" ];
  # Let remote builders pull dependencies from their own substituters (e.g. attic cache)
  # instead of having nix copy everything over SSH.
  nix.settings.builders-use-substitutes = true;
  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "26.05";
}
