{ config, lib, pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    curl
    git
    htop
    tmux
    wget
  ];
}
