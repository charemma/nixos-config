# Guide.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

All operations go through the justfile. The host defaults to "north".

```
just rebuild          # nixos-rebuild switch (apply immediately)
just boot             # apply on next boot only
just test             # test config, auto-rollback on next boot
just dry              # dry-run, show what would change
just diff             # diff current vs new generation (uses nvd)
just update           # nix flake update
just gc               # garbage collect old generations
```

All rebuild commands require sudo and operate via `nixos-rebuild --flake .#<host>`.

## Architecture

Flake-based NixOS config on nixpkgs unstable. Three flake inputs: nixpkgs, nixos-hardware, and raspberry-pi-nix.

**Hosts:**
- `north` (x86_64) -- build workstation, imports core, desktop, remote-access, infosec
- `framework` (x86_64) -- Framework Laptop 12, portable pentest machine, imports core, desktop, remote-access, infosec, laptop. Uses nixos-hardware for firmware/fingerprint
- `vps` (x86_64) -- VPS for charemma.de, Docker host, imports core + remote-access. Uses qemu-guest profile
- `rpi5` (aarch64) -- headless Raspberry Pi 5 server, imports core + remote-access only

**Host configs** (`hosts/<name>/configuration.nix`) own: bootloader, networking, locale, user account, and select which modules to import.

**Modules** (`modules/`) are functional groupings, each a standalone NixOS module:
- `core.nix` -- base packages (git, neovim, tmux, just, etc.) and shell setup
- `desktop.nix` -- display/WM (i3 via lightdm + niri as Wayland alt), GUI apps, input config
- `remote-access.nix` -- SSH + xRDP (niri-session), firewall port 3389
- `infosec.nix` -- security/pentest tooling (nmap, metasploit, hashcat, burpsuite, etc.)
- `laptop.nix` -- power management (TLP), backlight, lid switch, battery thresholds, touchpad

Adding a new host: create `hosts/<name>/configuration.nix` (+ `hardware-configuration.nix` for physical machines), add entry to `flake.nix` nixosConfigurations, then `just rebuild <name>`. The rpi5 host uses raspberry-pi-nix for kernel/bootloader/firmware and can be cross-built from x86 with binfmt emulation. The framework host uses nixos-hardware for Framework-specific firmware, fingerprint, and power profiles. The vps host uses the qemu-guest profile for KVM virtualization.

## Related Repos

User-level config lives outside this repo:
- **nix-home** -- home-manager packages (user-space)
- **dotfiles** -- config files via chezmoi

System-level packages go here, user-level packages go in nix-home.
