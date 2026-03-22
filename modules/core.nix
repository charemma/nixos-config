{ config, lib, pkgs, ... }:

{
  programs.vim.enable = true;

  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    arp-scan
    chezmoi
    curl
    git
    htop
    starship
    tmux
    wget
  ];
}
