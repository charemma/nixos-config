# incus.nix -- Incus for disposable lab VMs (sandbox research, multi-distro)
#
# VMs come from the Incus image server (images:ubuntu/24.04/cloud,
# images:fedora/41/cloud, ...) and are configured with plain cloud-init
# user-data, so the same user-data works on any other cloud-init host.
#
# Incus on NixOS requires the nftables firewall backend
# (networking.nftables.enable); modules with iptables extraCommands must use
# networking.firewall.extraInputRules instead. NixOS reloads only its own
# tables (flushRuleset stays false), so rules other tools add survive a reload.
#
# Storage lives on /home: the root partition is small (same reason Docker
# keeps its data-root there).
{ ... }:
let
  storageDir = "/home/incus/storage-pools/default";
  bridge = "incusbr0";
in
{
  networking.nftables.enable = true;

  virtualisation.incus = {
    enable = true;
    # Applied on every boot; existing objects are updated, not recreated.
    preseed = {
      networks = [
        {
          name = bridge;
          type = "bridge";
          config = {
            "ipv4.address" = "10.77.0.1/24";
            "ipv4.nat" = "true";
            "ipv6.address" = "none";
          };
        }
      ];
      storage_pools = [
        {
          name = "default";
          driver = "dir";
          config.source = storageDir;
        }
      ];
      profiles = [
        {
          name = "default";
          devices = {
            eth0 = {
              name = "eth0";
              network = bridge;
              type = "nic";
            };
            root = {
              path = "/";
              pool = "default";
              type = "disk";
            };
          };
        }
      ];
    };
  };

  # DHCP and DNS from the Incus bridge to its guests.
  networking.firewall.trustedInterfaces = [ bridge ];

  systemd.tmpfiles.rules = [ "d ${storageDir} 0711 root root -" ];

  # incus-admin grants full control of the daemon (root-equivalent).
  charemma.extraGroups = [ "incus-admin" ];
}
