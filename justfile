mod infra 'infra/vps/justfile'

_default:
    @just --list

# rebuild and switch (auto-detects darwin/nixos)
switch host="":
    #!/usr/bin/env bash
    if [[ "$(uname)" == "Darwin" ]]; then
        sudo darwin-rebuild switch --flake "$(pwd)#macbook"
    else
        host="${1:-$(hostname)}"
        sudo nixos-rebuild switch --flake "$(pwd)#${host}"
        sudo systemctl restart nix-daemon
    fi

# deploy vps config to charemma.de (builds remotely)
deploy:
    nix shell 'nixpkgs#nixos-rebuild' -c nixos-rebuild switch --flake "$(pwd)#vps" --target-host charemma@charemma.de --build-host charemma@charemma.de --sudo

# build rpi5 sd card image (requires binfmt on build host)
build-rpi5:
    nix build .#nixosConfigurations.rpi5.config.system.build.sdImage

# push latest build result to binary cache
push cache="main":
    attic push {{cache}} ./result

# push full system closure to binary cache
push-system host="north" cache="main":
    nix build ".#nixosConfigurations.{{host}}.config.system.build.toplevel" --no-link --print-out-paths | xargs attic push {{cache}}

# update flake inputs
update:
    nix flake update --flake "$(pwd)"

# garbage collect old generations
gc:
    sudo nix-collect-garbage -d
