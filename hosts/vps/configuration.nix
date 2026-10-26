# vps -- Hetzner cloud VM (x86_64-linux)
#
# modulesPath is a special argument pointing to the nixpkgs/nixos/modules directory.
# Used here to import the qemu-guest profile which adds virtio drivers and guest tools.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    # NixOS built-in profile that optimises the system for running inside QEMU/KVM.
    (modulesPath + "/profiles/qemu-guest.nix")
    # Declarative disk partitioning via disko (used during nixos-anywhere install).
    ./disko-config.nix
    ../../modules/core.nix
    ../../modules/syncthing-nixos.nix
    ../../modules/tailscale.nix
    ../../modules/monitoring.nix
    ../../modules/users.nix
    # Custom NixOS service module for k3s + Traefik + cert-manager.
    ../../services/k3s
  ];

  boot.loader.systemd-boot.enable = true;
  # Allows NixOS to write the EFI boot entry on first install.
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "vps";
  # useDHCP lets the cloud provider's network assign an IP automatically.
  networking.useDHCP = true;

  time.timeZone = "Europe/Berlin";
  i18n.defaultLocale = "en_US.UTF-8";

  # 4GB, no cushion for the box's own memory pressure -- 2026-08-17
  # incident: k3s/kine (SQLite) queries stalled under memory pressure, cascading
  # into lease-update failures, NodeNotReady flapping, and apiserver TLS
  # handshake timeouts (even on loopback). No swap meant the kernel had no
  # slack and thrashed instead. Declares the swapfile created live during
  # the incident so it survives a rebuild/reboot.
  swapDevices = [{
    device = "/swapfile";
    size = 4096;
  }];

  # Options for the custom k3s service module in services/k3s.
  services.k3s-server = {
    enable = true;
    domain = "charemma.de";
    acmeEmail = "me@charemma.de";
    # TLS-ALPN-01 cannot pass Cloudflare's proxy (#42). The token Secret is
    # seeded by platform infra/k8s-init (config cloudflareDnsToken).
    acmeDnsChallenge = {
      provider = "cloudflare";
      credentialsSecret = "traefik-acme-dns";
    };
    extraSANs = [ "vps.tail48929d.ts.net" ];
    # HSTS on all public sites; Middleware lives in platform gitops/manifests/traefik-middlewares
    websecureMiddlewares = [ "kube-system-hsts@kubernetescrd" ];
    # charemma.de, security, ai and zeddl are proxied by Cloudflare; trust its
    # X-Forwarded-For so logs and apps see visitors instead of Cloudflare edges.
    trustedProxies = import ../../services/k3s/cloudflare-ips.nix;
    # GoAccess dashboard for the access log, port-forward only (tailnet API).
    accessLogDashboard = true;
  };

  # bash is enabled so the root user (which defaults to bash) has a functional shell.
  programs.bash.enable = true;
  programs.zsh.enable = true;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "charemma" ];
  };

  system.stateVersion = "26.05";
}
