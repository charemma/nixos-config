# services/k3s/default.nix -- custom NixOS service module for k3s + Traefik + Let's Encrypt
#
# This is a proper NixOS module with declared options, not just a plain config file.
# It can be enabled per-host with `services.k3s-server.enable = true`.
{ config, lib, pkgs, ... }:

let
  # Convention: store the module's own options under a short name `cfg`
  # so you don't have to write config.services.k3s-server.xyz everywhere.
  cfg = config.services.k3s-server;
in {
  # Declare the options this module exposes. Other modules (or hosts) set these.
  options.services.k3s-server = {
    # lib.mkEnableOption creates a boolean option named `enable` with a description.
    # This is the standard NixOS pattern for toggling a service on/off.
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

  # lib.mkIf makes the entire config block conditional.
  # Nothing below is evaluated or applied unless cfg.enable = true.
  config = lib.mkIf cfg.enable {
    services.k3s = {
      enable = true;
      role = "server";
      # toString converts the list to a space-separated string of flags.
      # --tls-san adds the domain as a Subject Alternative Name to the k3s API cert,
      # so kubectl can connect via the domain name instead of only the IP.
      extraFlags = toString [
        "--tls-san=${cfg.domain}"
      ];
    };

    # k3s serves HTTP (for ACME HTTP-01 challenge), HTTPS, and the Kubernetes API.
    networking.firewall.allowedTCPPorts = [ 80 443 6443 ];

    # k3s bundles Traefik as the default ingress controller via a HelmChart resource.
    # This systemd oneshot service drops a HelmChartConfig into k3s's auto-deploy directory
    # so Traefik picks it up and configures Let's Encrypt automatically.
    systemd.services.k3s-traefik-config = {
      description = "Deploy Traefik HelmChartConfig for Let's Encrypt";
      # Run after k3s is up so the manifests directory exists.
      after = [ "k3s.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        # oneshot: run once and exit. systemd considers the service active after it exits.
        Type = "oneshot";
        # Keep the service in "active" state after the script finishes
        # so systemd doesn't try to restart it.
        RemainAfterExit = true;
      };
      # pkgs.writeText creates a file in the Nix store from an inline string.
      # The ${...} interpolations inject the runtime option values into the YAML.
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
