{ config, lib, pkgs, ... }:

{
  networking.hostName = "macbook";

  time.timeZone = "Europe/Athens";

  # Nix
  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    trusted-users = [ "charemma" ];
  };
  nixpkgs.config.allowUnfree = true;

  # Security
  security.pam.services.sudo_local.touchIdAuth = true;

  # System packages (user-level packages stay in nix-home)
  environment.systemPackages = with pkgs; [
    vim
  ];

  system.stateVersion = 6;
}
