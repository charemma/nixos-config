# binary-cache.nix -- configure the personal attic binary cache as a substituter
#
# A substituter is a cache Nix checks before building a derivation.
# If the store path already exists in the cache, it downloads instead of compiling.
{ config, lib, ... }:

{
  nix.settings = {
    # URL of the attic cache server. Nix will try this before falling back to building.
    substituters = [ "https://nix.charemma.de/main" ];
    # The public key to verify that downloaded store paths actually came from our cache.
    # Format: <cache-name>:<base64-encoded-public-key>
    trusted-public-keys = [
      "main:IRUYNlrph4qBjaoO79uXivgGPZVsemrRQaWph965JqY="
    ];
  };
}
