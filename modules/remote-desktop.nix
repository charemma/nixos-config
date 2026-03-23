{ config, lib, pkgs, ... }:

{
  services.xrdp.enable = true;
  services.xrdp.defaultWindowManager = "niri-session";

  networking.firewall.allowedTCPPorts = [ 3389 ];

  environment.systemPackages = with pkgs; [
    xrdb
  ];
}
