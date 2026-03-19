_default:
    @just --list

# rebuild and switch to new NixOS configuration
rebuild host="north":
    sudo nixos-rebuild switch --flake "$(pwd)#{{host}}"
    sudo systemctl restart nix-daemon

# rebuild and switch macbook (nix-darwin)
rebuild-mac:
    sudo darwin-rebuild switch --flake "$(pwd)#macbook"

# rebuild but only activate on next boot
boot host="north":
    sudo nixos-rebuild boot --flake "$(pwd)#{{host}}"

# test new configuration (rollback on next boot)
test host="north":
    sudo nixos-rebuild test --flake "$(pwd)#{{host}}"

# deploy vps config to charemma.de
deploy-vps:
    nix shell nixpkgs#nixos-rebuild -c nixos-rebuild switch --flake "$(pwd)#vps" --target-host charemma@charemma.de --build-host charemma@charemma.de --sudo

# apply k8s manifests to vps
deploy-web:
    cat "$HOME/code/charemma-web/k8s/"*.yaml | ssh charemma@charemma.de "sudo kubectl apply -f -"

# build rpi5 sd card image (requires binfmt on build host)
build-rpi5:
    nix build .#nixosConfigurations.rpi5.config.system.build.sdImage

# push latest build result to binary cache
push cache="main":
    attic push {{cache}} ./result

# push full system closure to binary cache
push-system host="north" cache="main":
    nix build ".#nixosConfigurations.{{host}}.config.system.build.toplevel" --no-link --print-out-paths | xargs attic push {{cache}}

# show what would change
dry host="north":
    nixos-rebuild dry-activate --flake "$(pwd)#{{host}}"

# update flake inputs (nixpkgs etc.)
update:
    nix flake update --flake "$(pwd)"

# diff between current and new generation
diff:
    nixos-rebuild build --flake "$(pwd)#north" && nvd diff /run/current-system result

# list generations
generations:
    sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# garbage collect old generations
gc:
    sudo nix-collect-garbage -d
