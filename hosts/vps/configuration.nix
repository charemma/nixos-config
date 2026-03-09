{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
    ./disko-config.nix
    ../../modules/core.nix
    ../../modules/remote-access.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "vps";
  networking.useDHCP = true;
  networking.firewall.allowedTCPPorts = [ 80 443 6443 ];

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";

  # k3s lightweight kubernetes
  services.k3s = {
    enable = true;
    role = "server";
    extraFlags = toString [
      "--tls-san=charemma.de"
    ];
  };

  # Traefik Let's Encrypt config via HelmChartConfig (k3s auto-deploy)
  systemd.services.k3s-traefik-config = {
    description = "Deploy Traefik HelmChartConfig for Let's Encrypt";
    after = [ "k3s.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      cp ${pkgs.writeText "traefik-config.yaml" ''
        apiVersion: helm.cattle.io/v1
        kind: HelmChartConfig
        metadata:
          name: traefik
          namespace: kube-system
        spec:
          valuesContent: |-
            additionalArguments:
              - "--certificatesresolvers.letsencrypt.acme.email=info@charemma.de"
              - "--certificatesresolvers.letsencrypt.acme.storage=/data/acme.json"
              - "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
      ''} /var/lib/rancher/k3s/server/manifests/traefik-config.yaml
    '';
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
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPDM0X4KGLF8cE9S6qTGxZeSXBijJ9eeWp0lXwNkF6bS charemma@macbook"
    ];
  };

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  programs.bash.enable = true;
  programs.zsh.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "26.05";
}
