# Plan: aiagent Product

AI agent running OpenClaw (backed by Claude) on a Raspberry Pi, provisioned as a NixOS SD card image.

## Ziel

Einen autonomen Assistenten auf einem Raspi betreiben, der 24/7 laeuft, per Telegram erreichbar ist, Obsidian-Notes lesen/schreiben kann (via Syncthing), Mails abrufen kann, und GitHub-Repos verwaltet.

## Architektur

```
Mac / North
  Obsidian Vault ──syncthing──► Raspi (aiagent)
                                  ├── OpenClaw (systemd service)
                                  │     ├── Claude API (backend)
                                  │     ├── Telegram Bot
                                  │     ├── Gmail / ProtonMail Bridge
                                  │     └── GitHub (gh CLI)
                                  └── Syncthing (notes sync)
```

## Repo-Struktur (nach bestehendem Pattern)

```
apps/openclaw/
  flake.nix          # baut OpenClaw als Nix-Paket (buildNpmPackage)
  module.nix         # NixOS-Modul: services.openclaw mit Optionen
  README.md

products/aiagent/
  flake.nix          # importiert platform-modules + openclaw
  configuration.nix  # hostname, services.openclaw enable = true, syncthing
  justfile           # build / flash / deploy (wie airsensor)
  README.md
```

## Tasks

- [ ] **apps/openclaw/flake.nix** -- OpenClaw als `buildNpmPackage` derivation
  - OpenClaw von GitHub fetchen (fetchFromGitHub mit Hash)
  - `npm install` / `npm build` als Nix-Build
  - Binary in `$out/bin/openclaw`

- [ ] **apps/openclaw/module.nix** -- NixOS-Modul `services.openclaw`
  - Optionen: `enable`, `configFile`, `dataDir`
  - systemd service mit `DynamicUser = true`, `StateDirectory`
  - Secrets per `EnvironmentFile` (API-Keys kommen via agenix/sops)

- [ ] **Secrets-Strategie entscheiden** -- `agenix` oder `sops-nix`?
  - Secrets: `ANTHROPIC_API_KEY`, `TELEGRAM_BOT_TOKEN`, Gmail credentials
  - Beide sind im Repo schon nicht vorhanden -- neu einfuehren
  - Empfehlung: `agenix` (simpler, SSH-key-basiert, gut zu nixos-iot)

- [ ] **products/aiagent/configuration.nix**
  ```nix
  networking.hostName = "aiagent";
  services.openclaw.enable = true;
  services.syncthing = { ... };  # notes sync mit Mac/North
  ```

- [ ] **products/aiagent/flake.nix** -- nach airsensor-Pattern:
  ```nix
  inputs = {
    nixpkgs.url = "...";
    platform.url = "path:../../modules";
    openclaw.url = "path:../../apps/openclaw";
  };
  ```

- [ ] **products/aiagent/justfile** -- `build`, `flash`, `deploy` (identisch zu airsensor)

- [ ] **Root flake.nix + justfile updaten** -- aiagent als neues Product registrieren

## Offene Entscheidungen

### ProtonMail vs Gmail
- **Gmail**: App Password + IMAP -- straightforward, funktioniert sofort
- **ProtonMail**: braucht `protonmail-bridge` als zweiten systemd-Service (headless mode)
  - Moeglich, aber aufwendiger; Bridge muss einmalig interaktiv authentifiziert werden
  - **Empfehlung**: mit Gmail anfangen, ProtonMail Bridge spaeter als optionales Modul

### OpenClaw Packaging
- OpenClaw ist ein Node.js-Projekt (npm) -- `buildNpmPackage` in nixpkgs
- Muss einmalig `npmDepsHash` berechnet werden (`prefetch-npm-deps`)
- Alternative: als fetchTarball + shellScript wrapper, falls Build zu komplex

### Syncthing Konfiguration
- Syncthing laeuft schon auf Mac/North -- airagent als neues Device hinzufuegen
- Folder: `~/notes` (Obsidian Vault) bidirektional
- NixOS hat `services.syncthing` built-in -- deklarativ konfigurierbar
- Device-Key beim ersten Boot generieren, dann am Mac manuell eintragen (einmalig)

### Board
- Welcher Raspi? Pi 4 oder Pi 5?
- `bsp-rpi.nix` ist aktuell fuer RPi 5 -- ggff. anpassen

## Erste Schritte beim naechsten Mal

1. OpenClaw GitHub-Repo anschauen um zu verstehen wie es gepackaged wird
   - `https://github.com/psteinroe/openclaw` oder aehnlich -- URL pruefen
2. `apps/openclaw/flake.nix` anlegen
3. `npmDepsHash` berechnen mit `prefetch-npm-deps package-lock.json`
4. `module.nix` nach `apps/airdata/module.nix` als Vorlage

## Referenz

- Bestehendes App-Pattern: `apps/airdata/` (Go) -- Vorlage fuer module.nix / flake.nix Struktur
- Bestehendes Product-Pattern: `products/airsensor/` -- Vorlage fuer configuration.nix / justfile
- CLAUDE.md im Repo-Root hat alle Konventionen dokumentiert
