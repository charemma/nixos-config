# tailscale.nix -- WireGuard-based mesh VPN via Tailscale
#
# Enables the Tailscale daemon and opens the necessary firewall ports.
# After deploying, run `sudo tailscale up` once on each host to authenticate.
#
# On hosts with pinned nixpkgs (e.g. aiagent/rpi), pass tailscale-pkg via
# specialArgs to get the current version from nixpkgs-unstable.
{ config, lib, pkgs, tailscale-pkg ? pkgs.tailscale, ... }:

{
  # Use the explicitly passed package when available (nixpkgs-unstable),
  # otherwise fall back to the host's own pkgs.tailscale.
  services.tailscale = {
    enable = true;
    package = tailscale-pkg;
  };

  # Allow Tailscale's UDP port through the firewall for direct peer connections.
  networking.firewall.allowedUDPPorts = [ config.services.tailscale.port ];

  # Trust the Tailscale interface so services listening on it don't need extra
  # firewall rules. Traffic on tailscale0 is already authenticated by WireGuard.
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
}
