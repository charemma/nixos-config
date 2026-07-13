# CLAUDE.md

## What this is

NixOS system configurations for all personal hosts: north (workstation), macbook (laptop), vps (Hetzner), rpi5, aiagent (RPi5 AI assistant). Managed as a Nix flake with modular configs under `modules/` and per-host configs under `hosts/`.

## Git workflow for this repo

This repo is edited from multiple machines (north, macbook, aiagent). To avoid merge conflicts:

1. **Always `git pull` before making changes.** If there are uncommitted local changes, stash them first.
2. **Work on feature branches.** Never commit directly to main unless it's a trivial one-line fix.
3. **Keep branches focused.** One concern per branch -- don't let scope creep in. If something unrelated comes up, make a separate branch.
4. **Commit and push before switching machines.** Don't leave dirty worktrees. Either commit, stash, or discard.
5. **Check the branch still makes sense.** Before committing, review what's on the branch. If it has grown beyond its original scope, split it up.
6. **Don't rebase branches that are shared across machines.** Rebase only local-only branches. Shared branches get merged, not rebased.

## Architecture

- `flake.nix` -- all hosts defined here, inputs managed centrally
- `modules/` -- shared NixOS modules (core.nix, dev.nix, desktop.nix, users.nix, etc.)
- `hosts/<name>/` -- per-host configuration.nix and justfile
- `justfile` -- top-level, loads per-host justfiles via `mod`

## Key patterns

- `nixpkgs` (unstable) is used for north, macbook, vps
- `nixpkgs-rpi` (pinned) is used for rpi5 and aiagent (raspberry-pi-nix compatibility)
- Packages that need a newer version than nixpkgs-rpi provides are passed via `specialArgs` from current nixpkgs (e.g. nodejs-current, whisper-cpp-pkg, claude-code-pkg)
- `claude-code-nix` flake provides always-up-to-date Claude Code on all hosts
- OpenClaw is installed via npm (`bootstrap-tools`) because the nix-openclaw packaging is broken

## Deployment

```
just north::rebuild      # rebuild NixOS on north (run locally)
just mac::rebuild        # rebuild nix-darwin on macbook (run locally)
just vps::deploy         # deploy to VPS over SSH
just aiagent::deploy     # deploy to aiagent RPi over SSH (nix copy as root)
just aiagent::build      # build SD card image (remote builder or binfmt)
just aiagent::flash      # flash SD card image to device
```

## Build strategy for aarch64 (RPi) images

- Initial full build: use a remote builder (Hetzner cloud) -- `just aiagent::build` with NIX_BUILDERS set
- Iterative changes: build locally via binfmt emulation -- most of the closure is cached in the local nix store
- Remote builders need `builders-use-substitutes = true` on the client (north/macbook) to pull from cache instead of SSH

## Syncthing warning

If a host that participates in Syncthing is reflashed or has its data wiped, **stop Syncthing on ALL devices first**. A device with an empty filesystem will propagate deletions to all other devices. This has caused data loss before.
