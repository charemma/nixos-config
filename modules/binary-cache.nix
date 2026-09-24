# binary-cache.nix -- personal S3 binary cache (platform/infra/nix-cache)
#
# Remote builders push everything they build there, so every host can
# substitute it instead of rebuilding (kernel, firmware, system closures for
# the RPi hosts are not on cache.nixos.org). Reads are public over HTTPS, no
# AWS credentials needed. Runs on NixOS and nix-darwin.
#
# extra-* keeps the nixpkgs default substituter (cache.nixos.org) in place
# instead of replacing the list.
{ ... }:

{
  nix.settings = {
    extra-substituters = [
      "https://charemma-nix-cache.s3.eu-central-1.amazonaws.com"
    ];
    extra-trusted-public-keys = [
      "charemma-nix-cache-1:R/svQq6DM5KAHVlkP1w7tXXcH3VhyV5iJFu+7OV/c6U="
    ];
  };
}
