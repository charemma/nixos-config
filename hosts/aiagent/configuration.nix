{ config, lib, pkgs, nodejs-current, ... }:

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

  # npm global installs go to ~/.npm-global (nix store is read-only)
  environment.sessionVariables.NPM_CONFIG_PREFIX = "$HOME/.npm-global";
  environment.sessionVariables.PATH = [ "$HOME/.npm-global/bin" ];

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "charemma" ];
  };

  # OpenClaw gateway -- AI assistant reachable via Telegram
  # nix-openclaw packaging is broken (missing plugin manifests), so we install via npm.
  # First run: install-openclaw && openclaw setup
  # Runs as a user-level systemd service under charemma.
  environment.systemPackages = with pkgs; [
    nodejs-current
    (pkgs.writeShellScriptBin "install-openclaw" ''
      export NPM_CONFIG_PREFIX="$HOME/.npm-global"
      mkdir -p "$NPM_CONFIG_PREFIX"
      npm install -g openclaw@latest
      echo 'Add to PATH: export PATH="$HOME/.npm-global/bin:$PATH"'
    '')
  ];

  # Syncthing -- keeps Obsidian vault in sync with Mac/North
  services.syncthing = {
    enable = true;
    user = "charemma";
    dataDir = "/home/charemma";
    configDir = "/home/charemma/.config/syncthing";
    openDefaultPorts = true;
  };

  system.stateVersion = "26.05";
}
