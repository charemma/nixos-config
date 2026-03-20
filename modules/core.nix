{ config, lib, pkgs, ... }:

{
  programs.vim.enable = true;
  environment.variables.EDITOR = lib.mkDefault "vim";

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
