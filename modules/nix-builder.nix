# nix-builder.nix -- provide the dedicated Hetzner remote builder private key.
#
# The matching public key authorizes the `nix` user on the Hetzner builders
# (managed in the infra repo under nix-builder/). Remote builds run through the
# nix-daemon as root, so the private key is deployed to a root-readable path.
#
# The builder instance itself is selected at runtime via NIX_BUILDERS (see the
# `_builders` recipe in the nixos-config justfile and `nix-builder::builders-env`
# in infra), so the dynamic instance IP stays out of the system configuration.
#
# Requires the sops-nix module and a configured age identity on the host
# (see hosts/macbook/configuration.nix: sops.age.sshKeyPaths).
{ ... }:

{
  sops.secrets."nix-builder-key" = {
    sopsFile = ../secrets/nix-builder.yaml;
    key = "nix-builder-key";
    path = "/etc/nix/nix-builder_ed25519";
    mode = "0600";
    owner = "root";
  };
}
