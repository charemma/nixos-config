{ config, lib, pkgs, modulesPath, charemma-web, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disko-config.nix
    ../../modules/core.nix
    ../../modules/remote-access.nix
  ];

  boot.loader.grub.enable = true;

  networking.hostName = "vps";
  networking.useDHCP = true;
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";

  # Caddy web server for charemma.de
  services.caddy = {
    enable = true;
    virtualHosts."charemma.de" = {
      serverAliases = [ "www.charemma.de" ];
      extraConfig = ''
        root * ${charemma-web}/html
        file_server
        encode gzip

        header {
          X-Content-Type-Options nosniff
          X-Frame-Options DENY
          Referrer-Policy strict-origin-when-cross-origin
        }
      '';
    };
  };

  # User
  users.groups.charemma.gid = 1000;
  users.users.charemma = {
    isNormalUser = true;
    uid = 1000;
    group = "charemma";
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
    initialHashedPassword = "";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICbWNkSKK+ytdkDGGbol8VWlKOSJgZh+GLGWgGaDsEJv charemma@north"
    ];
  };

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  programs.zsh.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "26.05";
}
