{ config, lib, pkgs, ... }:

{
  options.charemma.extraGroups = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
    description = "Extra groups for the charemma user beyond wheel.";
  };

  config = {
    users.groups.charemma.gid = 1000;
    users.users.charemma = {
      isNormalUser = true;
      uid = 1000;
      group = "charemma";
      extraGroups = [ "wheel" ] ++ config.charemma.extraGroups;
      shell = pkgs.zsh;
      initialHashedPassword = "";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICbWNkSKK+ytdkDGGbol8VWlKOSJgZh+GLGWgGaDsEJv charemma@north"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPDM0X4KGLF8cE9S6qTGxZeSXBijJ9eeWp0lXwNkF6bS charemma@macbook"
      ];
    };

    security.sudo = {
      enable = true;
      wheelNeedsPassword = false;
    };
  };
}
