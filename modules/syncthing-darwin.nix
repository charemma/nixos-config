# syncthing-darwin.nix -- nix-darwin has no services.syncthing module, so
# macbook runs syncthing as a user LaunchAgent instead. See
# syncthing-nixos.nix for the NixOS equivalent.
{ config, pkgs, ... }:

let
  homeDir = "/Users/charemma";
in
{
  environment.systemPackages = [ pkgs.syncthing ];

  launchd.user.agents.syncthing = {
    command = "${pkgs.syncthing}/bin/syncthing -no-browser -no-restart -logflags=0 -home=${homeDir}/.config/syncthing";
    serviceConfig = {
      RunAtLoad = true;
      KeepAlive = true;
      StandardOutPath = "${homeDir}/Library/Logs/syncthing.log";
      StandardErrorPath = "${homeDir}/Library/Logs/syncthing.log";
    };
  };
}
