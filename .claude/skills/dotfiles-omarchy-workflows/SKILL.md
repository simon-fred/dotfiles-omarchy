---
name: dotfiles-omarchy-workflows
description: Use when working in the dotfiles-omarchy repo — covers adding a new dotfile, adding pacman/AUR packages, the idempotence contract for install scripts, push workflow (gh user switch between simon-wcg and simon-fred), and which paths must NOT be versioned.
---

# dotfiles-omarchy workflows

## Overview

Personliga Omarchy-configs för Yoga Pro 9. Två klasser av filer:

- **Symlinkade dotfiles** under `home/<path>` — länkas till `$HOME/<path>` av `install.sh`.
- **Setup-scripts** (`install*.sh`, `wireguard-setup/`, `yoga-pro-9-audio-fix/`, `usb-webcam-bandwidth-fix/`) — köras manuellt, måste vara idempotenta.

Allt i `install*.sh` ska kunna köras flera gånger utan sidoeffekter.

## Adding a new dotfile

1. Flytta filen till `home/<samma path som under $HOME>` (t.ex. `home/.config/foo/bar.conf`).
2. Lägg till relativa pathen i `FILES`-arrayn i `install.sh`.
3. Kör `./install.sh` — befintlig fil i `$HOME` backupas till `<fil>.backup.<timestamp>` innan symlinken skapas.

## Adding a package

`install-omarchy-apps.sh` har två arrays:

- `PACKAGES` → pacman, installeras via `omarchy pkg add`.
- `AUR_PACKAGES` → AUR, installeras via `omarchy pkg aur add` (eftersom `omarchy pkg add` inte hittar AUR-paket).

Lägg till paketet i rätt array, alfabetisk ordning. Loopen är redan idempotent (kör `pacman -Q` som check — fungerar för båda eftersom installerade AUR-paket dyker upp i pacman-DB:n).

Verifiera AUR-paketnamn via:

```sh
curl -s 'https://aur.archlinux.org/rpc/?v=5&type=search&by=name&arg=<name>' | jq '.results[].Name'
```

## Idempotence contract

Allt i `install*.sh` måste vara säkert att köra om. Mönster som används i repot:

- **Paket:** `pacman -Q "$pkg" >/dev/null 2>&1` — om sant, skippa.
- **Symlinks:** `[[ -L "$dst" && "$(readlink "$dst")" == "$src" ]]` — om sant, skippa.
- **Desktop-filer / webapps:** `[[ -f "$HOME/.local/share/applications/${name}.desktop" ]]`.
- **Befintliga regular files vid symlinkning:** backupa till `<fil>.backup.<timestamp>` innan `ln -s`, så användarens manuella ändringar inte tappas.

Loggning: prefix `=` för "redan där", `-` för "installeras/skapas", `+` för "klart", `↳` för backup, `✗` för fel. Summary i slutet.

## Paths som INTE ska versioneras

- `~/.config/omarchy/current/*` — runtime-state som Omarchy skriver till. Lägg **aldrig** in i `FILES`-arrayn.
- WireGuard private key — `wireguard-setup/` läser configen från `~/Downloads/` och kopierar till `/etc/wireguard/`. Configen committas inte.
- Andra hemligheter (tokens, lösenord, ssh-nycklar).

Om du är osäker: kolla `.gitignore` och `wireguard-setup/README.md`.

## Push workflow

Default `gh`-konto är `simon-wcg` (jobb). Detta är ett `simon-fred/*`-repo. Före push:

```sh
gh auth switch --user simon-fred
git push
gh auth switch --user simon-wcg
```

Glöm inte switcha tillbaka. Övriga regler:

- Aldrig `--no-verify` om inte explicit ombedd.
- Aldrig force-push till `main`.
- Commits via HEREDOC för korrekt formattering (se Claude Codes default-mönster).

## Language conventions

- **Kod, kommentarer, `echo`-output:** svenska. T.ex. `echo "- installerar paket: ${to_add[*]}"`. Matchar befintlig stil.
- **Commit subject + body:** engelska. Även om diffen rör svensk text.
- **Filnamn och variabelnamn:** engelska (`AUR_PACKAGES`, `skipped_pkgs`).
