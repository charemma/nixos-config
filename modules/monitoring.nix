{ config, lib, pkgs, ... }:

{
  services.prometheus.exporters.node = {
    enable = true;
    enabledCollectors = [ "systemd" "cpu" "meminfo" "diskstats" "filesystem" "netdev" "loadavg" "time" ];
    port = 9100;
    openFirewall = true;
  };
}
