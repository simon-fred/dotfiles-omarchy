# dotfiles-omarchy

Personliga Omarchy-configs (Hyprland + shell) för Yoga Pro 9. Se [README.md](README.md) för översikt.

## Symlink-modellen (viktigt!)

Filerna under `home/<path>` i detta repo symlinkas till `$HOME/<path>` av `install.sh`. Det betyder att t.ex. `~/.bashrc`, `~/.config/hypr/bindings.conf` och `~/.claude/settings.json` är symlinks **in i detta repo**.

**Redigera alltid källan här** (`home/.bashrc`, `home/.config/hypr/bindings.conf`, …), aldrig symlink-targeten. Att redigera via symlinken fungerar i praktiken (skriver tillbaka till källan), men gör det otydligt vad som är versionerat — och vissa verktyg följer inte symlinks korrekt.

## GitHub-identitet vid push

Default aktivt `gh`-konto på den här maskinen är `simon-wcg` (jobb). Detta repo ligger under `simon-fred/*` (privat).

**Innan push:**

```sh
gh auth switch --user simon-fred
git push
gh auth switch --user simon-wcg
```

Glöm inte att switcha tillbaka — annars kommer nästa jobbrelaterade `gh`-kommando att gå mot fel konto.

## Commit-språk

Subject och body på **engelska**, även om koden, kommentarerna och script-output är på svenska. Matchar resten av commit-historiken.

## Mer

För djupare workflows (lägga till ny dotfile, lägga till paket, idempotens-kontraktet för install-scripts, vad som **inte** ska versioneras) — invokera skillen `dotfiles-omarchy-workflows`.
