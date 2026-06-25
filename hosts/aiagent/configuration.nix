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
  networking.networkmanager.enable = true;

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

  time.timeZone = "Europe/Athens";
  i18n.defaultLocale = "en_US.UTF-8";

  users.groups.charemma.gid = 1000;
  users.users.charemma = {
    isNormalUser = true;
    uid = 1000;
    group = "charemma";
    extraGroups = [ "wheel" "networkmanager" ];
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
  ];

  system.stateVersion = "26.05";
}
