{ config, lib, pkgs, ... }:

{
  services.prometheus.exporters.node = {
    enable = true;
    enabledCollectors = [ "systemd" "cpu" "memory" "diskstats" "filesystem" "netdev" "loadavg" "time" ];
    port = 9100;
    openFirewall = true;
  };
}
