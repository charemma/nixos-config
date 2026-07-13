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

# update flake inputs
update:
    nix flake update --flake "$(pwd)"

# garbage collect old generations
gc:
    sudo nix-collect-garbage -d
