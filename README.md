# nixos-config

NixOS system configurations managed via flakes. Modular setup with per-host configurations and shared modules.

## Structure

```
hosts/
  north/                  workstation (AMD, dual-boot with Debian)
    configuration.nix     host-specific config (user, boot, networking)
    hardware-configuration.nix
modules/
  core.nix                essentials (git, neovim, tmux, gh, ...)
  desktop.nix             GUI (niri, kitty, brave, waybar, ...)
  remote-access.nix       SSH, xRDP
```

## Usage

```
just rebuild              rebuild and switch to new configuration
just boot                 rebuild, activate on next boot
just test                 test config (rollback on next boot)
just update               update flake inputs
just gc                   garbage collect old generations
```

## Bootstrap

On a fresh NixOS install:

```
git clone git@github.com:charemma/nixos-config.git ~/code/nixos-config
~/code/nixos-config/bootstrap.sh north
```

## Related

- [nix-home](https://github.com/charemma/nix-home) -- user-level packages via home-manager
- [dotfiles](https://github.com/charemma/dotfiles) -- config files via chezmoi
