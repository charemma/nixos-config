# core.nix -- base settings shared across all hosts (NixOS and nix-darwin)
#
# Module arguments: config, lib, pkgs are injected by the NixOS module system.
# pkgs gives access to all nixpkgs packages.
# lib provides utility functions (mkDefault, mkOption, types, ...).
{ config, lib, pkgs, ... }:

{
  imports = [ ./binary-cache.nix ];

  # Weekly garbage collection. north's root filled up during a deploy because
  # the store had never been collected (42 GB of dead paths). Keep a month of
  # generations so a rollback stays possible; the schedule option differs
  # between NixOS (dates) and nix-darwin (interval).
  nix.gc = {
    automatic = true;
    options = "--delete-older-than 30d";
  } // (if pkgs.stdenv.isDarwin
    then { interval = { Weekday = 0; Hour = 4; Minute = 0; }; }
    else { dates = "weekly"; });

  services.openssh.enable = true;

  programs.vim.enable = true;

  # lib.mkForce overrides the nano default that nixpkgs sets in
  # programs/environment.nix. Both would be mkDefault otherwise and collide.
  environment.variables.EDITOR = lib.mkForce "vim";

  # Registers zsh in /etc/shells so it can be used as a login shell.
  # Required before setting shell = pkgs.zsh on any user.
  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    arp-scan
    chezmoi
    curl
    fd
    gcc
    git
    gnumake
    gh
    htop
    jq
    mitmproxy
    python3
    ripgrep
    starship
    tmux
    tree
    unzip
    wget
    zip
  ];
}
