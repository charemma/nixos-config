{ config, lib, pkgs, ... }:

{
  programs.vim.enable = true;
  environment.sessionVariables.EDITOR = lib.mkDefault "vim";

  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    chezmoi
    curl
    fastfetch
    fzf
    gh
    git
    htop
    just
    starship
    tmux
    wget
  ];
}
