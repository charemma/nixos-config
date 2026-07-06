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

    # The node IP k3s advertises to the cluster. Must be the Tailscale IP so
    # the server can reach this agent for kubelet, exec, and pod networking.
    # Find it with: tailscale ip -4
    nodeIP = lib.mkOption {
      type = lib.types.str;
      description = "Tailscale IP of this node (100.x.x.x). Run 'tailscale ip -4' to find it.";
    };

    tokenFile = lib.mkOption {
      type = lib.types.path;
      default = "/etc/k3s/token";
      description = "Path to the k3s join token file. Copy from /var/lib/rancher/k3s/server/node-token on the server.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.k3s = {
      enable = true;
      role = "agent";
      serverAddr = "https://${cfg.serverHost}:6443";
      tokenFile = cfg.tokenFile;
      extraFlags = toString (
        lib.optional (cfg.nodeIP != "") "--node-ip=${cfg.nodeIP}"
      );
    };

    # k3s agent must start after Tailscale so serverHost is reachable.
    systemd.services.k3s = {
      after = [ "tailscaled.service" ];
      wants = [ "tailscaled.service" ];
    };
  };
}
