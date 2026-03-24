# dev.nix -- developer tools for workstations (north, macbook)
#
# anker and claude-code-nix are flake inputs, passed in via specialArgs in flake.nix.
# That's why they appear as named arguments here instead of being accessed through pkgs.
{ config, lib, pkgs, anker, claude-code-nix, ... }:

{
  # npm global installs go to ~/.npm-global (nix store is read-only)
  environment.sessionVariables.NPM_CONFIG_PREFIX = "$HOME/.npm-global";
  environment.sessionVariables.PATH = [ "$HOME/.npm-global/bin" ];

  # with pkgs; brings nixpkgs packages into scope.
  # anker/claude-code-nix use .packages.${pkgs.system}.default to select the right arch.
  environment.systemPackages = with pkgs; [
    anker.packages.${pkgs.system}.default
    claude-code-nix.packages.${pkgs.system}.default
    attic-client
    bat
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

    # OpenClaw installed via npm (nix-openclaw packaging is broken).
    # Run bootstrap-tools after first install or to update.
    (pkgs.writeShellScriptBin "bootstrap-tools" ''
      export NPM_CONFIG_PREFIX="''${NPM_CONFIG_PREFIX:-$HOME/.npm-global}"
      mkdir -p "$NPM_CONFIG_PREFIX"
      echo "Installing npm tools to $NPM_CONFIG_PREFIX..."
      npm install -g openclaw@latest
      echo "Done."
    '')
  ];
}
