_default:
    @just --list

# rebuild and switch to new configuration
rebuild host="north":
    sudo nixos-rebuild switch --flake "$(pwd)#{{host}}"

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
