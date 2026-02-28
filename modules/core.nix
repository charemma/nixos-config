{ config, lib, pkgs, ... }:

{
  programs.vim.enable = true;
  environment.sessionVariables.EDITOR = lib.mkDefault "vim";

  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    curl
    fastfetch
    gh
    git
    htop
    just
    tmux
    wget
  ];
}
