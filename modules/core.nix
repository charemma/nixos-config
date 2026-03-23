{ config, lib, pkgs, ... }:

{
  services.openssh.enable = true;

  programs.vim.enable = true;

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
    python3
    ripgrep
    starship
    tmux
    tree
    wget
  ];
}
