# remote-access.nix -- SSH and RDP access
{ config, lib, pkgs, ... }:

{
  # XRDP is a Remote Desktop Protocol server, allowing GUI access from Windows/macOS RDP clients.
  services.xrdp.enable = true;
  # The window manager to launch when an RDP session starts.
  services.xrdp.defaultWindowManager = "niri-session";

  # Open the RDP port in the firewall. 3389 is the standard RDP port.
  networking.firewall.allowedTCPPorts = [ 3389 ];

  environment.systemPackages = with pkgs; [
    # xrdb loads X resources (colours, fonts) into the X server's database.
    # Needed so RDP sessions pick up the correct theme settings.
    xrdb
  ];
}
