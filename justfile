_default:
    @just --list --list-submodules

mod north 'hosts/north/justfile'
mod mac 'hosts/macbook/justfile'
mod vps 'hosts/vps/justfile'
mod aiagent 'hosts/aiagent/justfile'

# internal: use NIX_BUILDERS if set, otherwise fall back to local linux-builder
_builders:
    @echo "${NIX_BUILDERS:-ssh-ng://linux-builder aarch64-linux /etc/nix/builder_ed25519 4 1 - - -}"

# Pushing needs the cache signing key at $NIX_CACHE_KEY (default below) and AWS
# credentials for the nix-cache-push user in the environment, e.g.
# eval "$(just -f ../platform/justfile cache::env)". Nix only uploads paths the
# bucket does not have yet, but it hashes the whole closure first: a no-op push
# of a system closure took 26 minutes on the RPi. Remote builders upload what
# they build on their own, so this is only for paths built locally.
_cache_url := "s3://charemma-nix-cache?region=eu-central-1"
_cache_key := env("NIX_CACHE_KEY", env("HOME") + "/.config/nix/charemma-nix-cache.sec")

# push a store path and its closure to the S3 binary cache
cache-push path:
    @nix copy --to "{{ _cache_url }}&secret-key={{ _cache_key }}" {{ path }} || echo "warning: cache push failed (signing key at {{ _cache_key }}? AWS credentials in env?)"

# update flake inputs
update:
    nix flake update --flake "$(pwd)"

# garbage collect old generations
gc:
    sudo nix-collect-garbage -d
