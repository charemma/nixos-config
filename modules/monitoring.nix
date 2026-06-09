# monitoring.nix -- Prometheus node_exporter as a shared module
#
# Exposes host metrics on port 9100 for scraping by VictoriaMetrics (running in k3s
# on vps). Reachability is by design constrained to the Tailnet: tailscale.nix sets
# networking.firewall.trustedInterfaces = [ "tailscale0" ], so 9100 is reachable from
# tailnet peers but blocked on every other interface. openFirewall is intentionally
# false so this stays true on hosts with a public NIC (vps).
{ config, lib, pkgs, ... }:

{
  services.prometheus.exporters.node = {
    enable = true;
    enabledCollectors = [
      "systemd"
      "cpu"
      "meminfo"
      "diskstats"
      "filesystem"
      "netdev"
      "loadavg"
      "time"
    ];
    port = 9100;
    openFirewall = false;
  };
}
