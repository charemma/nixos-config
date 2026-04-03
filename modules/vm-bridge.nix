# vm-bridge.nix -- network bridge for QEMU VMs on north
#
# A bridge (br0) sits between the physical NIC and QEMU VMs.
# VMs join the bridge and get their own IP from the router via DHCP,
# so they appear as real devices on the local network.
{ config, lib, pkgs, ... }:

{
  # Create a bridge interface br0 and attach the physical NIC to it.
  # All traffic that would go to eno1 now flows through the bridge.
  networking.bridges.br0.interfaces = [ "eno1" ];

  # The bridge itself gets an IP via DHCP (instead of eno1 directly).
  networking.interfaces.br0.useDHCP = true;

  # NixOS scripted networking sets PartOf=network-setup.service on bridge units.
  # PartOf stops the bridge when network-setup restarts during nixos-rebuild,
  # but does NOT restart it afterwards -- leaving the bridge dead until reboot.
  # Removing PartOf keeps the bridge alive across rebuilds.
  systemd.services.br0-netdev.unitConfig.PartOf = lib.mkForce "";
  systemd.services.network-addresses-br0.unitConfig.PartOf = lib.mkForce "";

  # QEMU checks this file before allowing a VM to use a bridge.
  # Without this entry, QEMU refuses to attach VMs to br0.
  environment.etc."qemu/bridge.conf".text = ''
    allow br0
  '';

  # Shortcut for scanning the bridge network. -I br0 scans the bridge interface, -l scans the local subnet.
  # Needs sudo because arp-scan requires raw socket access.
  environment.shellAliases.arp-scan = "sudo arp-scan -I br0 -l";
}
