{
  config,
  lib,
  pkgs,
  whisper-cpp-pkg,
  tailscale-pkg,
  ...
}:

{
  imports = [
    ../../modules/core.nix
    ../../modules/networking-resilience.nix
    ../../modules/syncthing-nixos.nix
    ../../modules/dev.nix
    ../../modules/nixvim.nix
    ../../modules/tailscale.nix
    ../../modules/monitoring.nix
    ../../services/k3s/agent.nix
    # Override tailscale with current version from nixpkgs-unstable
    # (nixpkgs-rpi ships an outdated 1.78.1)
    { services.tailscale.package = tailscale-pkg; }
  ];

  raspberry-pi-nix.board = "bcm2712";

  # RPi5 kernel doesn't enable the memory cgroup controller by default --
  # containerd (bundled in k3s) needs it and fails hard without it:
  # "Error: failed to find memory cgroup (v2)". k3s-agent.service has been
  # crash-looping on every boot since this host was set up as a result
  # (found 2026-08-14, 231k+ restart attempts). Classic RPi gotcha, same
  # fix as the well-known Raspbian workaround.
  boot.kernelParams = [
    "cgroup_memory=1"
    "cgroup_enable=memory"
  ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };

  networking.hostName = "aiagent";
  networking.networkmanager.enable = true;
  # Drop VPN plugins on this headless RPi5. The default NM plugin set pulls the
  # -gnome VPN variants (libnma, gtk4, webkitgtk) which take an hour to build
  # under aarch64 emulation and are useless without a GUI. Tailscale handles VPN.
  networking.networkmanager.plugins = lib.mkForce [ ];
  # nm-online times out during nixos-rebuild switch on headless hosts -- the check
  # is not meaningful when we administer the box over SSH anyway.
  systemd.services.NetworkManager-wait-online.enable = false;
  # Explicit nameservers so DNS works even if DHCP does not supply them or
  # tailscale runs with -DefaultRoute (only tailnet queries via 100.100.100.100).
  networking.nameservers = [
    "1.1.1.1"
    "8.8.8.8"
  ];

  # enable /etc/hosts editing
  environment.etc.hosts.enable = false;

  # Disable wifi radio while a wired link is up, re-enable when it drops.
  # Credentials are entered once on the device:
  #   nmcli device wifi connect <SSID> password <PWD>
  networking.networkmanager.dispatcherScripts = [
    {
      source = pkgs.writeShellScript "wifi-toggle-on-ethernet" ''
        action=$2
        case "$CONNECTION_TYPE" in
          802-3-ethernet) ;;
          *) exit 0 ;;
        esac
        case "$action" in
          up)
            ${pkgs.networkmanager}/bin/nmcli radio wifi off
            ;;
          down)
            if ! ${pkgs.networkmanager}/bin/nmcli -t -f TYPE,STATE device status \
                | grep -q '^ethernet:connected$'; then
              ${pkgs.networkmanager}/bin/nmcli radio wifi on
            fi
            ;;
        esac
      '';
    }
  ];

  services.k3s-agent = {
    enable = true;
    serverHost = "vps.tail48929d.ts.net";
    # Reserve this node for workloads that specifically need to run here
    # (particulate PM sensor via USB, or jobscout-scanner for its
    # residential IP -- login-based portal fetchers are less bot-suspicious
    # from a home IP than the vps's datacenter IP). Everything else must
    # run on the vps so power/net outages here don't take down web services
    # or the alerting path itself. Pods without a matching toleration will
    # not schedule; already-running pods without one will be evicted at
    # next reconcile.
    nodeTaints = [ "dedicated=home:NoSchedule" ];
    nodeLabels = {
      "sensor-type" = "particulate";
      "location" = "kitchen";
      "home-network" = "true";
      # Obsidian vault lives on this host (Syncthing) -- jobscout's
      # obsidian-writer pins to it via nodeSelector, see
      # jobscout/k8s/obsidian-writer-deployment.yaml
      "vault-access" = "true";
    };
  };

  hardware.bluetooth.enable = true;

  time.timeZone = "Europe/Athens";
  i18n.defaultLocale = "en_US.UTF-8";

  users.groups.charemma.gid = 1000;
  users.users.charemma = {
    isNormalUser = true;
    uid = 1000;
    group = "charemma";
    extraGroups = [
      "wheel"
      "video"
      "networkmanager"
      "bluetooth"
    ];
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

  programs.zsh.enable = true;

  # nix-ld provides a dynamic linker shim so pre-compiled binaries (e.g. Claude Code
  # auto-updates) can run on NixOS without patching their ELF interpreter.
  programs.nix-ld.enable = true;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [ "charemma" ];
  };

  # Extra packages not covered by dev.nix
  environment.systemPackages = with pkgs; [
    wakeonlan # send WoL magic packet to wake north: wakeonlan <north-MAC>
    whisper-cpp-pkg
    ffmpeg
    lsof
    mutagen # this host is the /code sync hub; spokes reach it over SSH
  ];

  # aiagent is the Mutagen sync hub: it holds the canonical /code, and north and
  # macbook sync against it over SSH (see modules/mutagen-code.nix). No daemon is
  # needed here -- the spokes' daemons deploy the mutagen agent over SSH. This dir
  # is the source of truth, so it must exist.
  systemd.tmpfiles.rules = [
    "d /code 0755 charemma charemma -"
  ];

  system.stateVersion = "26.05";
}
