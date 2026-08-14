{ config, lib, pkgs, whisper-cpp-pkg, tailscale-pkg, ... }:

{
  imports = [
    ../../modules/core.nix
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
  boot.kernelParams = [ "cgroup_memory=1" "cgroup_enable=memory" ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };

  networking.hostName = "aiagent";
  networking.networkmanager.enable = true;
  # Drop VPN plugins on this headless RPi5. The default NM plugin set pulls the
  # -gnome VPN variants (libnma, gtk4, webkitgtk) which take an hour to build
  # under aarch64 emulation and are useless without a GUI. Tailscale handles VPN.
  networking.networkmanager.plugins = lib.mkForce [];
  # nm-online times out during nixos-rebuild switch on headless hosts -- the check
  # is not meaningful when we administer the box over SSH anyway.
  systemd.services.NetworkManager-wait-online.enable = false;
  # Explicit nameservers so DNS works even if DHCP does not supply them or
  # tailscale runs with -DefaultRoute (only tailnet queries via 100.100.100.100).
  networking.nameservers = [ "1.1.1.1" "8.8.8.8" ];

  # Disable wifi radio while a wired link is up, re-enable when it drops.
  # Credentials are entered once on the device:
  #   nmcli device wifi connect <SSID> password <PWD>
  networking.networkmanager.dispatcherScripts = [{
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
  }];

  services.k3s-agent = {
    enable = true;
    serverHost = "vps.tail48929d.ts.net";
    # Reserve this node for kitchen-local workloads only (particulate PM sensor,
    # future USB peripherals). Everything else must run on the vps so power/net
    # outages here don't take down web services or the alerting path itself.
    # Pods without a matching toleration will not schedule; already-running pods
    # without one will be evicted at next reconcile.
    nodeTaints = [ "dedicated=home:NoSchedule" ];
    nodeLabels = {
      "sensor-type" = "particulate";
      "location" = "kitchen";
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
    extraGroups = [ "wheel" "video" "networkmanager" "bluetooth" ];
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
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "charemma" ];
  };

  # Extra packages not covered by dev.nix
  environment.systemPackages = with pkgs; [
    wakeonlan  # send WoL magic packet to wake north: wakeonlan <north-MAC>
    whisper-cpp-pkg
    ffmpeg
    lsof
    motion
    v4l-utils
    # motion-test: grab a single frame and send it to Telegram via openclaw.
    # Use to verify the camera + delivery pipeline without waiting for motion.
    (writeShellScriptBin "motion-test" ''
      set -euo pipefail
      tmp=$(mktemp --suffix=.jpg)
      trap 'rm -f "$tmp"' EXIT
      ${pkgs.ffmpeg}/bin/ffmpeg -loglevel error -y -f v4l2 -i /dev/video0 \
        -frames:v 1 -vf "scale=1280:720" "$tmp"
      export PATH=${pkgs.nodejs}/bin:$PATH
      /home/charemma/.npm-global/bin/openclaw message send \
        --channel telegram \
        --target telegram:98836267 \
        --message "motion-test snapshot $(date +%H:%M:%S)" \
        --media "$tmp"
    '')
  ];

  # USB camera (Anker PowerConf C200 on /dev/video0).
  # Event-based recording with a Telegram alert (snapshot) per event via openclaw.
  # Runs as charemma so the hook can reach ~/.openclaw without sudo gymnastics.
  # nixpkgs-rpi ships the motion package but not the NixOS module, so we wire
  # up the systemd service by hand.

  # NFS server: export /code to all Tailscale peers (100.64.0.0/10 CGNAT range).
  # all_squash maps every client UID to anonuid=1000 (charemma) so north (uid 1000)
  # and macbook (different uid) both write as charemma. tailscale0 is already in
  # trustedInterfaces so no extra firewall rules are needed.
  services.nfs.server = {
    enable = true;
    exports = ''
      /code  100.64.0.0/10(rw,sync,no_subtree_check,all_squash,anonuid=1000,anongid=1000)
    '';
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/motion 0755 charemma charemma -"
    "d /code 0755 charemma charemma -"
  ];

  systemd.services.motion = let
    motionNotify = pkgs.writeShellScript "motion-telegram-notify" ''
      snapshot=$1
      event=$2
      export PATH=${pkgs.nodejs}/bin:$PATH
      ${pkgs.coreutils}/bin/timeout 30 \
        /home/charemma/.npm-global/bin/openclaw message send \
          --channel telegram \
          --target telegram:98836267 \
          --message "Bewegung erkannt (event $event)" \
          --media "$snapshot" \
        >/dev/null 2>&1 || true
    '';
    motionSettings = {
      videodevice = "/dev/video0";
      width = 1280;
      height = 720;
      framerate = 15;
      threshold = 1500;
      noise_level = 32;
      event_gap = 60;
      pre_capture = 150;
      post_capture = 30;
      picture_output = "first";
      movie_output = "on";
      movie_max_time = 30;
      target_dir = "/var/lib/motion";
      picture_filename = "%Y-%m-%d/%H%M%S-%v-%q";
      movie_filename = "%Y-%m-%d/%H%M%S-%v";
      snapshot_interval = 0;
      stream_localhost = "on";
      webcontrol_localhost = "on";
      on_picture_save = "${motionNotify} %f %v";
    };
    motionConf = pkgs.writeText "motion.conf"
      (lib.concatStringsSep "\n"
        (lib.mapAttrsToList (k: v: "${k} ${toString v}") motionSettings));
  in {
    description = "Motion video surveillance";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      User = "charemma";
      Group = "charemma";
      # zoom_absolute: 100 = no zoom, 400 = 4x. Tune after live preview.
      ExecStartPre = "${pkgs.v4l-utils}/bin/v4l2-ctl --device=/dev/video0 --set-ctrl=zoom_absolute=100";
      ExecStart = "${pkgs.motion}/bin/motion -n -c ${motionConf}";
      Restart = "on-failure";
      RestartSec = 5;
    };
  };

  systemd.services.motion-cleanup = {
    description = "Delete motion recordings older than 7 days";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.findutils}/bin/find /var/lib/motion -type f -mtime +7 -delete";
    };
  };
  systemd.timers.motion-cleanup = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
    };
  };

  system.stateVersion = "26.05";
}
