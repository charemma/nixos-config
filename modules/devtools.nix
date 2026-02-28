{ config, lib, pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  programs.bat.enable = true;

  environment.systemPackages = with pkgs; [
    claude-code
    curl
    git
    glow
    htop
    starship
    tmux
    wget
    yazi
  ];
}
