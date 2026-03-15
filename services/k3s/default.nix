{ config, lib, pkgs, ... }:

let
  cfg = config.services.k3s-server;
in {
  options.services.k3s-server = {
    enable = lib.mkEnableOption "k3s single-node server with Traefik and Let's Encrypt";

    domain = lib.mkOption {
      type = lib.types.str;
      description = "Primary domain for TLS SAN and ACME.";
    };

    acmeEmail = lib.mkOption {
      type = lib.types.str;
      description = "Email for Let's Encrypt certificate notifications.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.k3s = {
      enable = true;
      role = "server";
      extraFlags = toString [
        "--tls-san=${cfg.domain}"
      ];
    };

    networking.firewall.allowedTCPPorts = [ 80 443 6443 ];

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
                - "--certificatesresolvers.letsencrypt.acme.email=${cfg.acmeEmail}"
                - "--certificatesresolvers.letsencrypt.acme.storage=/data/acme.json"
                - "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
        ''} /var/lib/rancher/k3s/server/manifests/traefik-config.yaml
      '';
    };
  };
}
