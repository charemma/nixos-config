{ config, lib, pkgs, anker, ... }:

{
  environment.systemPackages = with pkgs; [
    anker.packages.${pkgs.system}.default
    attic-client
    bat
    claude-code
    direnv
    fastfetch
    fd
    fzf
    gh
    git
    glow
    jq
    just
    k9s
    kubectl
    lsd
    neovim
    nodejs
    ripgrep
    yazi
  ];
}
