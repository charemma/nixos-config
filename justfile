_default:
    @just --list

# rebuild and switch to new configuration
rebuild:
    sudo nixos-rebuild switch --flake $(pwd)#north

# rebuild but only activate on next boot
boot:
    sudo nixos-rebuild boot --flake $(pwd)#north

# test new configuration (rollback on next boot)
test:
    sudo nixos-rebuild test --flake $(pwd)#north

# show what would change
dry:
    nixos-rebuild dry-activate --flake $(pwd)#north

# update flake inputs (nixpkgs etc.)
update:
    nix flake update --flake $(pwd)

# diff between current and new generation
diff:
    nixos-rebuild build --flake $(pwd)#north && nvd diff /run/current-system result

# list generations
generations:
    sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# garbage collect old generations
gc:
    sudo nix-collect-garbage -d
