# dev.nix -- developer tools for workstations (north, macbook)
# anker is a flake input, passed in via specialArgs in flake.nix.
# Claude Code is installed via its self-updating binary (~/.local/bin/claude),
# not through Nix, so it always tracks the latest release.
{ config, lib, pkgs, anker, ... }:

{
  # npm global installs go to ~/.npm-global (nix store is read-only)
  environment.variables.NPM_CONFIG_PREFIX = "$HOME/.npm-global";
  # On NixOS this list gets merged into PATH; nix-darwin has no such merge and
  # would OVERWRITE the whole PATH (wiping /bin, /usr/bin, nix paths) -- which
  # breaks every shell. macOS shells get ~/.npm-global/bin from the dotfiles, so
  # only set this off darwin.
  environment.variables.PATH = lib.mkIf (!pkgs.stdenv.isDarwin) [ "$HOME/.npm-global/bin" ];

  # vim -> nvim alias for muscle memory (nixvim.nix sets EDITOR)
  environment.shellAliases.vim = "nvim";

  environment.systemPackages = with pkgs; [
    anker.packages.${pkgs.system}.default
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
    nodejs
    ripgrep
    tig
    yazi

    # Claude Code comes from the official native installer, not from Nix: it
    # updates itself on the `latest` channel, so new models work the day they
    # ship. Run once on a fresh host; afterwards the binary keeps itself current.
    (pkgs.writeShellScriptBin "bootstrap-tools" ''
      set -eu
      if [ -x "$HOME/.local/bin/claude" ]; then
        echo "claude already installed: $("$HOME/.local/bin/claude" --version)"
      else
        ${pkgs.curl}/bin/curl -fsSL https://claude.ai/install.sh | ${pkgs.bash}/bin/bash
      fi
    '')
  ];
}
