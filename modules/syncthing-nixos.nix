# syncthing-nixos.nix -- keeps the Obsidian vault and ~/.claude/ in sync
# across NixOS hosts. Folders are configured once via the web UI at
# http://localhost:8384 -- Nix only manages the daemon itself.
#
# nix-darwin has no services.syncthing module, see syncthing-darwin.nix
# for the macbook equivalent.
{ ... }:

{
  services.syncthing = {
    enable = true;
    user = "charemma";
    dataDir = "/home/charemma";
    configDir = "/home/charemma/.config/syncthing";
    openDefaultPorts = true;
  };
}
