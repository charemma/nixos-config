# dev.nix -- developer tools for workstations (north, macbook)
#
# `anker` is not from nixpkgs -- it's a flake input passed in via specialArgs in flake.nix.
# That's why it appears as a named argument here instead of being accessed through pkgs.
{ config, lib, pkgs, anker, ... }:

{
  # with pkgs; brings nixpkgs packages into scope.
  # anker.packages.${pkgs.system}.default selects the default package
  # for the current system architecture from the anker flake.
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
