# core.nix -- base settings shared across all hosts (NixOS and nix-darwin)
#
# Module arguments: config, lib, pkgs are injected by the NixOS module system.
# pkgs gives access to all nixpkgs packages.
# lib provides utility functions (mkDefault, mkOption, types, ...).
{ config, lib, pkgs, ... }:

{
  services.openssh.enable = true;

  programs.vim.enable = true;

  # lib.mkForce overrides the nano default that nixpkgs sets in
  # programs/environment.nix. Both would be mkDefault otherwise and collide.
  environment.variables.EDITOR = lib.mkForce "vim";

  # Registers zsh in /etc/shells so it can be used as a login shell.
  # Required before setting shell = pkgs.zsh on any user.
  programs.zsh.enable = true;

  # with pkgs; brings all packages into scope so we can write `curl` instead of `pkgs.curl`.
  # Syncthing -- keeps Obsidian vault and workspace in sync across hosts
  services.syncthing = {
    enable = true;
    user = "charemma";
    dataDir = "/home/charemma";
    configDir = "/home/charemma/.config/syncthing";
    openDefaultPorts = true;
  };

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
    python3
    ripgrep
    starship
    tmux
    tree
    wget
  ];
}
