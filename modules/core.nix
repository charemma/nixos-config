# core.nix -- base settings shared across all hosts (NixOS and nix-darwin)
#
# Module arguments: config, lib, pkgs are injected by the NixOS module system.
# pkgs gives access to all nixpkgs packages.
# lib provides utility functions (mkDefault, mkOption, types, ...).
{ config, lib, pkgs, ... }:

let
  # Rollback depth: the weekly GC keeps only this many system generations.
  keepSystemGenerations = 3;

  # Runs right before the weekly GC. NixOS hooks into systemd, nix-darwin into
  # launchd, and only the matching option set exists on each platform. The
  # check uses `options` inside an explicit `config` because branching on pkgs
  # here would recurse (pkgs itself depends on config).
  systemGenerationLimit = { config, lib, options, pkgs, ... }:
    let
      gc = config.nix.gc;
      nixBin = "${config.nix.package}/bin";
      pruneSystemGenerations = "${nixBin}/nix-env --delete-generations +${toString keepSystemGenerations} --profile /nix/var/nix/profiles/system";
    in
    {
      config = lib.mkMerge [
        (lib.optionalAttrs (options ? systemd) {
          systemd.services.nix-gc.preStart = lib.mkIf gc.automatic pruneSystemGenerations;
          # Boot menu matches the generations that survive the GC.
          boot.loader.systemd-boot.configurationLimit = keepSystemGenerations;
        })
        (lib.optionalAttrs (options ? launchd) {
          launchd.daemons.nix-gc.command = lib.mkIf gc.automatic (lib.mkForce (toString
            (pkgs.writeShellScript "nix-gc" ''
              ${pruneSystemGenerations}
              exec ${nixBin}/nix-collect-garbage ${gc.options}
            '')));
        })
      ];
    };
in
{
  imports = [ ./binary-cache.nix systemGenerationLimit ];

  # Weekly garbage collection. north's root filled up during a deploy because
  # the store had never been collected (42 GB of dead paths). Before each run
  # only the newest keepSystemGenerations system generations are kept (see
  # systemGenerationLimit); generations of other profiles go after a month.
  # The schedule option differs between NixOS (dates) and nix-darwin (interval).
  nix.gc = {
    automatic = true;
    options = "--delete-older-than 30d";
  } // (if pkgs.stdenv.hostPlatform.isDarwin
    then { interval = { Weekday = 0; Hour = 4; Minute = 0; }; }
    else { dates = "weekly"; });

  services.openssh.enable = true;

  programs.vim.enable = true;

  # lib.mkForce overrides the nano default that nixpkgs sets in
  # programs/environment.nix. Both would be mkDefault otherwise and collide.
  environment.variables.EDITOR = lib.mkForce "vim";

  # Registers zsh in /etc/shells so it can be used as a login shell.
  # Required before setting shell = pkgs.zsh on any user.
  programs.zsh.enable = true;

  environment.systemPackages = with pkgs; [
    arp-scan
    # agg turns asciinema recordings into GIFs; nixpkgs' plain `agg` is the
    # Anti-Grain Geometry C++ library, not this tool.
    asciinema-agg
    chezmoi
    curl
    fd
    gcc
    git
    gnumake
    gh
    htop
    jq
    # test_emudhra fails against the current CA bundle (certificate rejected);
    # unrelated to our use, so skip it until nixpkgs fixes the package.
    (mitmproxy.overridePythonAttrs (old: {
      disabledTests = (old.disabledTests or [ ]) ++ [ "test_emudhra" ];
    }))
    mpv
    python3
    ripgrep
    starship
    tmux
    tree
    unzip
    # Terminal recordings from scripted tapes. hiPrio because gobuster also
    # ships a bin/vhs (on north via infosec.nix) and would otherwise shadow it.
    (lib.hiPrio vhs)
    wget
    zip
  ];
}
