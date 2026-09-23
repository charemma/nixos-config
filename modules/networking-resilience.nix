# networking-resilience.nix -- keep a wired link from ever stranding a host.
#
# NetworkManager normally auto-connects a wired device, but a rebuild that
# activates a config where no wired connection ends up active leaves the
# interface DOWN. On a headless box (aiagent, rpi5) that means no network and no
# console -- exactly the end0-DOWN-after-rebuild incident on aiagent (2026-09-23).
#
# This declares an explicit, always-autoconnecting DHCP profile for wired
# ethernet. It is interface-agnostic (no interface-name) so it matches whatever
# the NIC is called on each host (eno1 on north, end0 on the Pis). Guarded on NM
# being enabled, so importing it on a host that manages the network another way
# is a no-op.
{ config, lib, ... }:
{
  networking.networkmanager.ensureProfiles.profiles.wired-default =
    lib.mkIf config.networking.networkmanager.enable {
      connection = {
        id = "wired-default";
        type = "ethernet";
        autoconnect = true;
        autoconnect-priority = 100;
      };
      ipv4.method = "auto";
      ipv6.method = "auto";
    };
}
