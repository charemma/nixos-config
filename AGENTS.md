# Repository Guidelines

## Project Structure & Module Organization

This repository contains declarative NixOS and nix-darwin system configurations.
`flake.nix` is the central entry point for inputs, dev shells, and host
definitions. Shared modules live in `modules/`, for example `core.nix`,
`dev.nix`, `desktop.nix`, `users.nix`, and `binary-cache.nix`.
Per-host configuration lives in `hosts/<name>/configuration.nix`, with local
recipes in `hosts/<name>/justfile`.

Hosts include `north`, `macbook`, `vps`, `rpi5`, and `aiagent`. Reusable
services live under `services/`, currently `services/k3s`. Static assets are in
`assets/`. There is no separate test tree; validate with Nix builds.

## Build, Test, and Development Commands

Use `just` as the primary command interface.

- `nix develop`: enter a shell with `just`, `kubectl`, `nodejs`, and `pulumi`.
- `just --list --list-submodules`: show top-level and host-specific recipes.
- `just north::rebuild`: build and switch the local `north` NixOS system.
- `just mac::rebuild`: build and switch the `macbook` nix-darwin config.
- `just vps::deploy`: deploy the VPS configuration over SSH.
- `just aiagent::build`: build the Raspberry Pi image for `aiagent`.
- `just push` or `just push-system <host>`: publish build closures to Attic.
- `just update`: update flake inputs.

Before changing a host, prefer:
`nix build .#nixosConfigurations.<host>.config.system.build.toplevel`.

## Coding Style & Naming Conventions

Use two-space indentation in Nix files. Keep module names lowercase and
descriptive, such as `remote-desktop.nix` or `binary-cache.nix`. Host
directories should match the flake configuration name. Prefer small modules and
comments that explain non-obvious system or hardware decisions. Use
`nixfmt-rfc-style` for Nix formatting.

## Testing Guidelines

There is no standalone test framework. Validate changes by evaluating or
building the affected host. For shared modules, build at least one importing
host, and add more when behavior differs across Linux, Darwin, or Raspberry Pi.
Avoid deployment before a successful local build.

## Commit & Pull Request Guidelines

Recent commits use concise Conventional Commit style:
`feat(nixvim): add markdown support`, `fix(nixvim): drop rustfmt`, or
`feat(north): enable tailscale`. Use a scope when the change is host- or
module-specific. Keep commits focused on one concern.

Pull requests should name the affected host or module, list validation commands,
and call out deployment or migration steps. Include screenshots only for visible
desktop changes.

## Security & Configuration Tips

Do not commit secrets, private keys, or generated credentials. Treat SSH keys,
Attic cache settings, and deployment recipes as sensitive. This repo is used
from multiple machines; pull before editing, avoid shared-branch rebases, and
do not overwrite unrelated local changes.
