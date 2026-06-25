_default:
    @just --list --list-submodules

mod north 'hosts/north/justfile'
mod mac 'hosts/macbook/justfile'
mod vps 'hosts/vps/justfile'
mod rpi5 'hosts/rpi5/justfile'
mod aiagent 'hosts/aiagent/justfile'

# internal: remote builder spec, only when NIX_BUILDERS is set (empty otherwise).
# Empty means each host builds with its own config: darwin via /etc/nix/machines
# (the linux-builder VM), linux natively or via binfmt. Set NIX_BUILDERS to
# offload to a remote builder (e.g. the Hetzner nix-builder).
_builders:
    @echo "${NIX_BUILDERS:-}"

# push all build results to binary cache
push cache="main":
    #!/usr/bin/env bash
    for dir in results/*/; do
        host=$(basename "$dir")
        echo "Publishing $host..."
        nix path-info -r "results/$host" | xargs attic push {{cache}}
    done

# push full system closure to binary cache
push-system host="north" cache="main":
    nix build ".#nixosConfigurations.{{host}}.config.system.build.toplevel" --no-link --print-out-paths | xargs attic push {{cache}}

# update flake inputs
update:
    nix flake update --flake "$(pwd)"

# garbage collect old generations
gc:
    sudo nix-collect-garbage -d
