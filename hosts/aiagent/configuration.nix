{ config, lib, pkgs, ... }:

{
  imports = [
    ../../modules/core.nix
    ../../modules/binary-cache.nix
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

  security.sudo = {
    enable = true;
    wheelNeedsPassword = false;
  };

  programs.zsh.enable = true;

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # OpenClaw gateway -- AI assistant reachable via Telegram
  # Secrets (ANTHROPIC_API_KEY, TELEGRAM_BOT_TOKEN) are in /etc/openclaw/secrets.env
  # Create that file manually on first boot -- it is not managed by Nix.
  services.openclaw-gateway = {
    enable = true;
    environmentFiles = [ "/etc/openclaw/secrets.env" ];
    config = {
      apiProviders = [ { type = "anthropic"; } ];
    };
  };

  # Syncthing -- keeps Obsidian vault in sync with Mac/North
  # On first boot: note the device ID from `syncthing show-config`, then add it on the Mac.
  services.syncthing = {
    enable = true;
    user = "charemma";
    dataDir = "/home/charemma";
    configDir = "/home/charemma/.config/syncthing";
    openDefaultPorts = true;
  };

  system.stateVersion = "26.05";
}
