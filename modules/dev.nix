{ config, lib, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
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
