_default:
    @just --list --list-submodules

mod north 'hosts/north/justfile'
mod mac 'hosts/macbook/justfile'
mod vps 'hosts/vps/justfile'
mod rpi5 'hosts/rpi5/justfile'
mod aiagent 'hosts/aiagent/justfile'

# internal: use NIX_BUILDERS if set, otherwise fall back to local linux-builder
_builders:
    @echo "${NIX_BUILDERS:-ssh-ng://linux-builder aarch64-linux /etc/nix/builder_ed25519 4 1 - - -}"

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
