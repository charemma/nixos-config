_default:
    @just --list --list-submodules

mod north 'hosts/north/justfile'
mod mac 'hosts/macbook/justfile'
mod vps 'hosts/vps/justfile'
mod rpi5 'hosts/rpi5/justfile'
mod aiagent 'hosts/aiagent/justfile'

# internal: builders string for `nix build --builders`.
# Precedence: NIX_BUILDERS env > reachable linux-builder SSH host > empty (local only).
# Empty string tells nix to use no remote builders, so aarch64 builds fall back to
# local binfmt emulation.
_builders:
    #!/usr/bin/env bash
    if [ -n "${NIX_BUILDERS:-}" ]; then
        echo "$NIX_BUILDERS"
    elif ssh -o ConnectTimeout=3 -o BatchMode=yes linux-builder true 2>/dev/null; then
        echo "ssh-ng://linux-builder aarch64-linux /etc/nix/builder_ed25519 4 1 - - -"
    else
        echo ""
    fi

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
