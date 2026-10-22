# services/k3s/default.nix -- custom NixOS service module for k3s + Traefik + Let's Encrypt
#
# This is a proper NixOS module with declared options, not just a plain config file.
# It can be enabled per-host with `services.k3s-server.enable = true`.
{ config, lib, pkgs, ... }:

let
  # Convention: store the module's own options under a short name `cfg`
  # so you don't have to write config.services.k3s-server.xyz everywhere.
  cfg = config.services.k3s-server;

  # Traefik CLI arguments, rendered one per line into the HelmChartConfig.
  traefikArgs = [
    "--certificatesresolvers.letsencrypt.acme.email=${cfg.acmeEmail}"
    "--certificatesresolvers.letsencrypt.acme.storage=/data/acme.json"
    "--certificatesresolvers.letsencrypt.acme.tlschallenge=true"
  ] ++ lib.optional (cfg.websecureMiddlewares != [ ])
    "--entrypoints.websecure.http.middlewares=${lib.concatStringsSep "," cfg.websecureMiddlewares}"
  ++ lib.optionals (cfg.trustedProxies != [ ]) (map
    (ep: "--entrypoints.${ep}.forwardedHeaders.trustedIPs=${lib.concatStringsSep "," cfg.trustedProxies}")
    [ "web" "websecure" ]);

  # Request headers kept in the access log, everything else is dropped.
  # CF-Connecting-IP is the reliable visitor IP behind Cloudflare; the
  # X-Forwarded-For chain can start with a value the client made up.
  accessLogHeaders = [ "User-Agent" "Referer" "CF-Connecting-IP" "X-Forwarded-For" ];

  accessLogDir = "/var/log/traefik";
  dashboard = import ./traefik-access-dashboard.nix { inherit lib; logDir = accessLogDir; };
  # JSON is valid YAML, so the sidecar values can be inlined as flow mappings.
  # Continuation lines are indented to match valuesContent in the YAML below.
  dashboardValues = lib.optionalString cfg.accessLogDashboard (lib.concatStringsSep "\n    " [
    "deployment:"
    "  additionalContainers: ${builtins.toJSON dashboard.containers}"
    "  additionalVolumes: ${builtins.toJSON dashboard.volumes}"
    "additionalVolumeMounts: ${builtins.toJSON dashboard.volumeMounts}"
  ]);
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

    extraSANs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Additional Subject Alternative Names for the k3s API cert (e.g. Tailscale hostnames).";
    };

    acmeEmail = lib.mkOption {
      type = lib.types.str;
      description = "Email for Let's Encrypt certificate notifications.";
    };

    websecureMiddlewares = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [ "kube-system-hsts@kubernetescrd" ];
      description = ''
        Traefik middlewares applied to every route on the websecure (HTTPS)
        entrypoint, e.g. HSTS. The Middleware resources must exist in the
        cluster before this is deployed, otherwise all websecure routes fail.
      '';
    };

    trustedProxies = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = lib.literalExpression "import ./cloudflare-ips.nix";
      description = ''
        CIDRs whose X-Forwarded-* headers Traefik keeps (e.g. a CDN in front
        of some hosts). Requests from anywhere else get these headers
        stripped, so clients cannot spoof their IP.
      '';
    };

    accessLogDashboard = lib.mkEnableOption ''
      a GoAccess dashboard for the Traefik access log, as sidecars in the
      Traefik pod (see traefik-access-dashboard.nix). Reach it with
      `kubectl -n kube-system port-forward deploy/traefik 8090 7890`
    '';
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
      # --flannel-iface pins Flannel's VXLAN VTEP to the Tailscale interface, matching
      # services/k3s/agent.nix. Without this, the server advertises its default (public)
      # interface as the VTEP endpoint, which agent nodes reachable only over Tailscale
      # (like aiagent) can't route to -- breaks cross-node pod traffic in that direction.
      extraFlags = toString (
        [ "--tls-san=${cfg.domain}" "--flannel-iface=tailscale0" ]
        ++ map (san: "--tls-san=${san}") cfg.extraSANs
      );
    };

    # k3s serves HTTP (for ACME HTTP-01 challenge) and HTTPS publicly.
    # The Kubernetes API (6443) is reachable ONLY via the Tailscale
    # interface -- the cluster is admin-only and must not be public.
    networking.firewall.allowedTCPPorts = [ 80 443 ];
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 6443 ];
    # Pods reach the API via the ClusterIP (10.43.0.1:443), which kube-proxy
    # DNATs to <node-ip>:6443. For pods on this node that traffic enters via
    # cni0, NOT tailscale0 -- without this rule the firewall drops it and
    # every in-cluster API client (Traefik, ArgoCD, operators) breaks with
    # i/o timeouts (2026-09-11 incident: all ingress routes gone, sites 404).
    # Cross-node pod traffic arrives via tailscale0 (flannel VTEP is pinned
    # there) and is already covered above.
    networking.firewall.interfaces.cni0.allowedTCPPorts = [ 6443 ];

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
                ${lib.concatMapStringsSep "\n      " (arg: "- \"${arg}\"") traefikArgs}
              # Bind 80/443 on the node via hostPort instead of a LoadBalancer
              # Service. ServiceLB (klipper-lb) MASQUERADEs every connection,
              # even with externalTrafficPolicy: Local, so apps behind Traefik
              # only saw 10.42.x instead of the client IP. hostPort binds all
              # interfaces, so public and tailnet traffic both still reach it.
              ports:
                web:
                  hostPort: 80
                websecure:
                  hostPort: 443
              service:
                type: ClusterIP
              # hostPort only works on this node (the only public one).
              nodeSelector:
                kubernetes.io/hostname: ${config.networking.hostName}
              # The new pod cannot start while the old one holds the host
              # ports, so replace instead of surge (short downtime on update).
              updateStrategy:
                rollingUpdate:
                  maxUnavailable: 1
                  maxSurge: 0
              # JSON access log on stdout, for visitor analysis and spotting
              # scans. Retention is whatever kubelet log rotation keeps.
              logs:
                access:
                  enabled: true
                  format: json
                  ${lib.optionalString cfg.accessLogDashboard "filePath: ${accessLogDir}/access.log"}
                  fields:
                    headers:
                      defaultmode: drop
                      names:
                        ${lib.concatMapStringsSep "\n              " (h: "${h}: keep") accessLogHeaders}
              ${dashboardValues}
        ''} /var/lib/rancher/k3s/server/manifests/traefik-config.yaml
      '';
    };
  };
}
