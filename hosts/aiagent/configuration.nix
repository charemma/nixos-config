{ config, lib, pkgs, whisper-cpp-pkg, tailscale-pkg, ... }:

{
  imports = [
    ../../modules/core.nix
    ../../modules/dev.nix
    ../../modules/nixvim.nix
    ../../modules/binary-cache.nix
    ../../modules/tailscale.nix
    ../../modules/monitoring.nix
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
    extraGroups = [ "wheel" "video" ];
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

  systemd.tmpfiles.rules = [
    "d /var/lib/motion 0755 charemma charemma -"
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
      pre_capture = 15;
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
