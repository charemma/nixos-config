# core.nix -- base settings shared across all hosts (NixOS and nix-darwin)
#
# Module arguments: config, lib, pkgs are injected by the NixOS module system.
# pkgs gives access to all nixpkgs packages.
# lib provides utility functions (mkDefault, mkOption, types, ...).
{ config, lib, pkgs, ... }:

let
  # Home directory differs between NixOS (/home) and nix-darwin (/Users).
  homeDir = if pkgs.stdenv.isDarwin then "/Users/charemma" else "/home/charemma";
in
{
  services.openssh.enable = true;

  programs.vim.enable = true;

  # lib.mkForce overrides the nano default that nixpkgs sets in
  # programs/environment.nix. Both would be mkDefault otherwise and collide.
  environment.variables.EDITOR = lib.mkForce "vim";

  # Registers zsh in /etc/shells so it can be used as a login shell.
  # Required before setting shell = pkgs.zsh on any user.
  programs.zsh.enable = true;

  # Syncthing keeps Obsidian vault and ~/.claude/ in sync across all hosts.
  # Folders (Obsidian vault, claude memory) are configured once via the web UI
  # at http://localhost:8384 -- Nix only manages the daemon itself.
  # openDefaultPorts is NixOS-only (nix-darwin has no firewall module).
  services.syncthing = {
    enable = true;
    user = "charemma";
    dataDir = homeDir;
    configDir = "${homeDir}/.config/syncthing";
  } // lib.optionalAttrs (!pkgs.stdenv.isDarwin) {
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
