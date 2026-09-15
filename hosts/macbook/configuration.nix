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
  # since Catalina. automountd always places autofs triggers for paths on the
  # sealed volume under /System/Volumes/Data (Apple bridges this for /home with
  # a firmlink, which only Apple can create). A bare "code" entry in
  # synthetic.conf only creates an empty directory on the sealed volume -- the
  # NFS mount then lands on /System/Volumes/Data/code while /code stays empty.
  # The two-column form creates a synthetic symlink /code ->
  # /System/Volumes/Data/code instead, reaching the actual autofs trigger
  # (same trick nix-darwin uses for /run in modules/system/base.nix).
  #
  # Unlike NixOS, nix-darwin does NOT auto-run arbitrary
  # system.activationScripts.<name> entries -- only a fixed hardcoded list
  # (see nix-darwin's activation-scripts.nix) actually gets wired into the
  # activation run. Custom logic has to hook into one of the three
  # designated extension points (preActivation/extraActivation/postActivation).
  system.activationScripts.postActivation.text = lib.mkAfter ''
      if ! grep -q '^/-[[:space:]]*/etc/auto_code' /etc/auto_master 2>/dev/null; then
        echo "adding /etc/auto_code direct map to /etc/auto_master..."
        printf '/-\t/etc/auto_code\t--timeout=600\n' | tee -a /etc/auto_master >/dev/null
      fi

      # migrate away from the old bare-directory entry
      if grep -q '^code$' /etc/synthetic.conf 2>/dev/null; then
        echo "removing bare code entry from /etc/synthetic.conf..."
        sed -i "" '/^code$/d' /etc/synthetic.conf
      fi

      if ! grep -q '^code[[:space:]]' /etc/synthetic.conf 2>/dev/null; then
        echo "setting up /code -> /System/Volumes/Data/code via /etc/synthetic.conf..."
        printf 'code\tSystem/Volumes/Data/code\n' | tee -a /etc/synthetic.conf >/dev/null
        /System/Library/Filesystems/apfs.fs/Contents/Resources/apfs.util -t || true
      fi

      if [[ -e /code && ! -L /code ]]; then
        printf >&2 'warning: /code is still a plain directory -- reboot required for the synthetic symlink to appear\n'
      fi
      /usr/sbin/automount -vc 2>/dev/null || true
  '';

  # The version of nix-darwin this config was first set up with.
  # Integer format (6) instead of the NixOS string format ("26.05").
  system.stateVersion = 6;
}
