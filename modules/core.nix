{ config, lib, pkgs, ... }:

{
  programs.vim.enable = true;
  environment.sessionVariables.EDITOR = lib.mkDefault "vim";

  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    chezmoi
    curl
    git
    htop
    starship
    tmux
    wget
  ];
}
