# macbook -- Apple M-series laptop (aarch64-darwin, managed via nix-darwin)
#
# nix-darwin mirrors the NixOS module system but targets macOS.
# Not all NixOS options are available -- darwin has its own equivalents.
{ config, lib, pkgs, ... }:

{
  imports = [
    ../../modules/core.nix
    ../../modules/dev.nix
  ];

  networking.hostName = "macbook";

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
  environment.etc."auto_master".text = ''
    +auto_master
    /home  auto_home  -nobrowse,hidefromfinder
    /-  /etc/auto_code  --timeout=600
  '';
  environment.etc."auto_code".text = ''
    /code  -resvport,soft,intr,timeo=30,retrans=2,vers=3  aiagent.tail48929d.ts.net:/code
  '';

  system.activationScripts.nfsCodeMount = {
    text = ''
      mkdir -p /code
      /usr/sbin/automount -vc 2>/dev/null || true
    '';
  };

  # The version of nix-darwin this config was first set up with.
  # Integer format (6) instead of the NixOS string format ("26.05").
  system.stateVersion = 6;
}
