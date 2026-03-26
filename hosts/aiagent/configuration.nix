{ config, lib, pkgs, nodejs-current, whisper-cpp-pkg, claude-code-pkg, ... }:

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

  # Claude Code via nix flake (always up to date, hourly builds)
  # OpenClaw via npm (nix-openclaw packaging is broken)
  # Run bootstrap-tools after first install or to update openclaw.
  environment.systemPackages = with pkgs; [
    claude-code-pkg
    nodejs-current
    whisper-cpp-pkg
    pkgs.ffmpeg
    pkgs.lsof
    (pkgs.writeShellScriptBin "bootstrap-tools" ''
      export NPM_CONFIG_PREFIX="''${NPM_CONFIG_PREFIX:-$HOME/.npm-global}"
      mkdir -p "$NPM_CONFIG_PREFIX"
      echo "Installing npm tools to $NPM_CONFIG_PREFIX..."
      npm install -g openclaw@latest
      echo "Done."
    '')
    (pkgs.writeShellScriptBin "sync-claude-token" ''
      # Syncs the Claude Code OAuth token to OpenClaw auth-profiles.
      # Claude Code refreshes tokens automatically; OpenClaw doesn't know about them.
      # Run this after `claude setup-token` or when the bot stops responding.
      CREDS="$HOME/.claude/.credentials.json"
      AUTH="$HOME/.openclaw/agents/main/agent/auth-profiles.json"
      if [ ! -f "$CREDS" ]; then
        echo "Error: $CREDS not found. Run 'claude setup-token' first."
        exit 1
      fi
      TOKEN=$(${pkgs.python3}/bin/python3 -c "
import json, sys
with open('$CREDS') as f:
    d = json.load(f)
t = d.get('claudeAiOauth', {}).get('accessToken', '')
if not t:
    print('No OAuth token found', file=sys.stderr)
    sys.exit(1)
print(t)
")
      if [ -z "$TOKEN" ]; then exit 1; fi
      ${pkgs.python3}/bin/python3 -c "
import json
with open('$AUTH') as f:
    profiles = json.load(f)
profiles['profiles']['anthropic:default'] = {
    'type': 'api_key',
    'provider': 'anthropic',
    'key': '$TOKEN'
}
with open('$AUTH', 'w') as f:
    json.dump(profiles, f, indent=2)
    f.write('\n')
print('Token synced to OpenClaw')
print('Token prefix: ' + '$TOKEN'[:15] + '...')
"
      echo "Restarting openclaw-gateway..."
      systemctl --user restart openclaw-gateway
      echo "Done."
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
