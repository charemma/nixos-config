# users.nix -- the charemma user, shared across all NixOS hosts
#
# This module uses the NixOS options system to let hosts extend the user
# without duplicating the whole user block. A host sets charemma.extraGroups
# and this module merges it in.
{ config, lib, pkgs, ... }:

let
  # The SSH public keys for all personal machines. Used as the default for all hosts.
  # A host can override charemma.authorizedKeys entirely or append to it.
  defaultKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICbWNkSKK+ytdkDGGbol8VWlKOSJgZh+GLGWgGaDsEJv charemma@north"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPDM0X4KGLF8cE9S6qTGxZeSXBijJ9eeWp0lXwNkF6bS charemma@macbook"
  ];
in {
  # `options` declares new NixOS options that other modules (or hosts) can set.
  # This is how you build configurable, reusable modules.
  options.charemma = {
    extraGroups = lib.mkOption {
      # lib.types.listOf lib.types.str validates that the value is a list of strings.
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Extra groups for the charemma user beyond wheel.";
    };

    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      # All personal machines by default. Override this on hosts that should be more restricted,
      # or append extra keys with: charemma.authorizedKeys = defaultKeys ++ [ "ssh-ed25519 ..." ];
      default = defaultKeys;
      description = "SSH public keys authorised to log in as charemma.";
    };
  };

  # When a module declares both `options` and actual settings, the settings
  # must go inside `config = { ... }` to keep them separate from the declarations.
  config = {
    users.groups.charemma.gid = 1000;

    users.users.charemma = {
      isNormalUser = true;
      uid = 1000;
      group = "charemma";
      # ++ appends the host-specific groups to the base list at evaluation time.
      # config.charemma.extraGroups reads back the option we declared above.
      extraGroups = [ "wheel" ] ++ config.charemma.extraGroups;
      shell = pkgs.zsh;
      initialHashedPassword = "";
      openssh.authorizedKeys.keys = config.charemma.authorizedKeys;
    };

    security.sudo = {
      enable = true;
      wheelNeedsPassword = false;
    };
  };
}
