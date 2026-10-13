# docker.nix -- Docker daemon for local container work
#
# Enables rootful Docker, adds charemma to the docker group (no sudo needed
# for the docker CLI) and keeps image/layer storage in check with a weekly prune.
{ config, lib, pkgs, ... }:

{
  virtualisation.docker = {
    enable = true;

    # Store images, layers and volumes on /home instead of /var/lib/docker.
    # The root partition is small; /home has plenty of room.
    daemon.settings.data-root = "/home/docker";

    # Weekly `docker system prune` so dangling images and stopped containers
    # don't pile up.
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  # Membership in the docker group grants root-equivalent access to the daemon.
  # The compose and buildx CLI plugins ship with the docker package already.
  charemma.extraGroups = [ "docker" ];
}
