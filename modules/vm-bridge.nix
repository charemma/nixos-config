{ config, lib, pkgs, ... }:

{
  # bridge for running QEMU VMs in the local network
  # VMs get their own IP via DHCP and can see real traffic

  networking.bridges.br0.interfaces = [ "eno1" ];
  networking.interfaces.br0.useDHCP = true;

  # allow QEMU to use the bridge
  environment.etc."qemu/bridge.conf".text = ''
    allow br0
  '';
}
