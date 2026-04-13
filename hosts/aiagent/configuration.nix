{ config, lib, pkgs, whisper-cpp-pkg, tailscale-pkg, bat-pkg, ... }:

{
  imports = [
    ../../modules/core.nix
    ../../modules/dev.nix
    ../../modules/nixvim.nix
    ../../modules/binary-cache.nix
    ../../modules/tailscale.nix
    # Override tailscale with current version from nixpkgs-unstable
    # (nixpkgs-rpi ships an outdated 1.78.1)
    { services.tailscale.package = tailscale-pkg; }
  ];

  raspberry-pi-nix.board = "bcm2712";

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };

  networking.hostName = "aiagent";
  networking.useDHCP = true;

  time.timeZone = "Europe/Athens";
  i18n.defaultLocale = "en_US.UTF-8";

  users.groups.charemma.gid = 1000;
  users.users.charemma = {
    isNormalUser = true;
    uid = 1000;
    group = "charemma";
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
    initialHashedPassword = "";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICbWNkSKK+ytdkDGGbol8VWlKOSJgZh+GLGWgGaDsEJv charemma@north"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPDM0X4KGLF8cE9S6qTGxZeSXBijJ9eeWp0lXwNkF6bS charemma@macbook"
    ];
  };

  # Root SSH access for nixos-rebuild deployments (nix copy --no-check-sigs needs root)
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICbWNkSKK+ytdkDGGbol8VWlKOSJgZh+GLGWgGaDsEJv charemma@north"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPDM0X4KGLF8cE9S6qTGxZeSXBijJ9eeWp0lXwNkF6bS charemma@macbook"
  ];

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  # Prometheus Node Exporter -- metrics on port 9100
  # Scraped by Prometheus on k3s via Tailscale (100.65.75.90:9100)
  services.prometheus.exporters.node = {
    enable = true;
    enabledCollectors = [ "systemd" "cpu" "memory" "diskstats" "filesystem" "netdev" "loadavg" "time" ];
    port = 9100;
    openFirewall = true;
  };

  programs.zsh.enable = true;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "charemma" ];
  };

  # Override bat from nixpkgs-rpi (0.24) with current nixpkgs (0.26+)
  # so --theme=auto and --theme-dark/--theme-light work in bat config.
  nixpkgs.overlays = [ (final: prev: { bat = bat-pkg; }) ];

  # Extra packages not covered by dev.nix
  environment.systemPackages = with pkgs; [
    whisper-cpp-pkg
    ffmpeg
    lsof
  ];

  system.stateVersion = "26.05";
}
