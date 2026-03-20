{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disko-config.nix
    ../../modules/core.nix
    ../../modules/binary-cache.nix
    ../../modules/users.nix
    ../../services/k3s
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "vps";
  networking.useDHCP = true;

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";

  services.k3s-server = {
    enable = true;
    domain = "charemma.de";
    acmeEmail = "me@charemma.de";
  };

  programs.bash.enable = true;
  programs.zsh.enable = true;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "charemma" ];
  };

  system.stateVersion = "26.05";
}
