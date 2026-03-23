# core.nix -- base settings shared across all hosts (NixOS and nix-darwin)
#
# Module arguments: config, lib, pkgs are injected by the NixOS module system.
# pkgs gives access to all nixpkgs packages.
# lib provides utility functions (mkDefault, mkOption, types, ...).
{ config, lib, pkgs, ... }:

{
  services.openssh.enable = true;

  programs.vim.enable = true;

  # lib.mkDefault sets a value that other modules can still override with a plain assignment.
  # Without mkDefault, two modules assigning the same option would cause a conflict error.
  # environment.variables sets it system-wide (in /etc/profile); sessionVariables is per-session only.
  environment.variables.EDITOR = lib.mkDefault "vim";

  # Registers zsh in /etc/shells so it can be used as a login shell.
  # Required before setting shell = pkgs.zsh on any user.
  programs.zsh.enable = true;

  # with pkgs; brings all packages into scope so we can write `curl` instead of `pkgs.curl`.
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
