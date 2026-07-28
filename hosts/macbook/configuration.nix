# macbook -- Apple M-series laptop (aarch64-darwin, managed via nix-darwin)
#
# nix-darwin mirrors the NixOS module system but targets macOS.
# Not all NixOS options are available -- darwin has its own equivalents.
{ config, lib, pkgs, ... }:

{
  imports = [
    ../../modules/core.nix
    ../../modules/syncthing-darwin.nix
    ../../modules/dev.nix
  ];

  networking.hostName = "macbook";

  # Required since nix-darwin's multi-user migration -- user-scoped options
  # (launchd.user.agents, homebrew, etc.) need to know which account they apply to.
  system.primaryUser = "charemma";

  time.timeZone = "Europe/Athens";

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "charemma" ];
    builders-use-substitutes = true;
  };
  # Allow packages with non-free licenses.
  nixpkgs.config.allowUnfree = true;

  # Starts a Linux VM in the background that acts as a remote builder.
  # Allows building x86_64-linux and aarch64-linux derivations from macOS.
  nix.linux-builder.enable = true;

  # Allow sudo via Touch ID instead of typing a password.
  # sudo_local is the PAM service used by the terminal sudo on macOS.
  security.pam.services.sudo_local.touchIdAuth = true;

  environment.systemPackages = with pkgs; [
    qemu  # run NixOS VMs locally for testing
  ];

  # NFS client: mount aiagent's ~/code at /code via macOS autofs.
  # Uses NFSv3 + resvport (macOS convention). all_squash on server maps every
  # incoming UID to charemma (1000), so access works regardless of local uid.
  #
  # /etc/auto_master ships with macOS and already has meaningful content
  # (auto_home, /Network/Servers, ...) -- nix-darwin refuses to overwrite
  # unmanaged files outright, so instead of declaring environment.etc."auto_master"
  # (which would claim ownership of the whole file), the activation script below
  # just ensures our one extra direct-map line is present, leaving the rest alone.
  environment.etc."auto_code".text = ''
    /code  -resvport,soft,intr,timeo=30,retrans=2,vers=3  aiagent.tail48929d.ts.net:/code
  '';

  # /code does not exist at boot -- "/" is the sealed, read-only system volume
  # since Catalina, so new top-level directories need a synthetic.conf firmlink
  # to the Data volume (same trick nix-darwin uses for /run in modules/system/base.nix).
  system.activationScripts.nfsCodeMount = {
    text = ''
      if ! grep -q '^/-[[:space:]]*/etc/auto_code' /etc/auto_master 2>/dev/null; then
        echo "adding /etc/auto_code direct map to /etc/auto_master..."
        printf '/-\t/etc/auto_code\t--timeout=600\n' | tee -a /etc/auto_master >/dev/null
      fi

      if ! grep -q '^code\b' /etc/synthetic.conf 2>/dev/null; then
        echo "setting up /code via /etc/synthetic.conf..."
        printf 'code\n' | tee -a /etc/synthetic.conf >/dev/null
        /System/Library/Filesystems/apfs.fs/Contents/Resources/apfs.util -t || true
      fi

      if [[ ! -d /code ]]; then
        printf >&2 'error: /code firmlink did not appear, a reboot may be required\n'
      else
        /usr/sbin/automount -vc 2>/dev/null || true
      fi
    '';
  };

  # The version of nix-darwin this config was first set up with.
  # Integer format (6) instead of the NixOS string format ("26.05").
  system.stateVersion = 6;
}
