# music.nix -- terminal music player for workstations (north, macbook).
# kew comes from the nixpkgs-latest flake input, so it can be kept current
# without updating the main nixpkgs lock.
{ pkgs, nixpkgs-latest, ... }:

let
  latestPkgs = nixpkgs-latest.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in
{
  environment.systemPackages = [
    latestPkgs.kew
  ];
}
