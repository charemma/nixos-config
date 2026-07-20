# services/k3s/agent.nix -- k3s worker node (agent role)
#
# Connects to a k3s server over Tailscale. Requires Tailscale to be enabled
# on the host (modules/tailscale.nix) and the join token placed at tokenFile.
{ config, lib, ... }:

let
  cfg = config.services.k3s-agent;
in {
  options.services.k3s-agent = {
    enable = lib.mkEnableOption "k3s agent (worker node)";

    serverHost = lib.mkOption {
      type = lib.types.str;
      description = "Tailscale FQDN of the k3s server, e.g. vps.tail48929d.ts.net";
    };

    tokenFile = lib.mkOption {
      type = lib.types.path;
      default = "/etc/k3s/token";
      description = "Path to the k3s join token file. Copy from /var/lib/rancher/k3s/server/node-token on the server.";
    };

    nodeTaints = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = [ "dedicated=home:NoSchedule" ];
      description = ''
        Taints applied to this node via `--node-taint`. Prevents pods without
        matching tolerations from scheduling here. Use to reserve a node for a
        specific workload class (e.g. a sensor host that must not run general
        cluster workloads that could squeeze the sensor pod out or, worse, keep
        running when the node is meant to be quiet).
      '';
    };

    nodeLabels = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      example = { "sensor-type" = "particulate"; "location" = "kitchen"; };
      description = ''
        Labels applied to this node via `--node-label`. Used by nodeSelector
        in workload manifests to pin pods to nodes with specific hardware
        (e.g. a USB sensor) or role.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.k3s = {
      enable = true;
      role = "agent";
      serverAddr = "https://${cfg.serverHost}:6443";
      tokenFile = cfg.tokenFile;
      extraFlags = toString (
        [ "--flannel-iface=tailscale0" ]
        ++ map (t: "--node-taint=${t}") cfg.nodeTaints
        ++ lib.mapAttrsToList (k: v: "--node-label=${k}=${v}") cfg.nodeLabels
      );
    };

    # k3s agent must start after Tailscale so serverHost is reachable.
    systemd.services.k3s = {
      after = [ "tailscaled.service" ];
      wants = [ "tailscaled.service" ];
    };
  };
}
