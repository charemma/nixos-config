# tailscale.nix -- WireGuard-based mesh VPN via Tailscale
#
# Enables the Tailscale daemon and opens the necessary firewall ports.
# After deploying, run `sudo tailscale up` once on each host to authenticate.
{ config, lib, pkgs, ... }:

{
  # Enable the Tailscale service (installs the package and starts tailscaled).
  services.tailscale.enable = true;

  # systemd-resolved is required so MagicDNS (100.100.100.100) can forward queries
  # to upstream resolvers. Without it tailscaled has no DNS manager to read system
  # resolvers from and external hostnames fail to resolve.
  services.resolved.enable = true;

  # Allow Tailscale's UDP port through the firewall for direct peer connections.
  networking.firewall.allowedUDPPorts = [ config.services.tailscale.port ];

  # Trust the Tailscale interface so services listening on it don't need extra
  # firewall rules. Traffic on tailscale0 is already authenticated by WireGuard.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
