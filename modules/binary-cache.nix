{ config, lib, ... }:

{
  nix.settings = {
    substituters = [ "https://nix.charemma.de/main" ];
    trusted-public-keys = [
      "main:IRUYNlrph4qBjaoO79uXivgGPZVsemrRQaWph965JqY="
    ];
  };
}
