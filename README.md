# dotfiles-omarchy

Personliga Omarchy-configs (Hyprland + shell) för Yoga Pro 9. Plus ljudfix-paketet som lapp-fixar TAS2781-högtalarna.

## Versionerade filer

Symlinkas från detta repo till `$HOME` av `./install.sh`:

- `~/.bashrc`, `~/.bash_profile`
- `~/.config/hypr/{monitors,input,bindings,looknfeel,autostart}.conf` — de fem filerna som `hyprland.conf` source:ar
- `~/.config/omarchy/branding/{about,screensaver}.txt`
- `~/.config/omarchy/extensions/menu.sh`

`~/.config/omarchy/current/` versioneras **inte** — det är runtime-state som Omarchy skriver till.

## Bootstrap (första gången)

```sh
gh repo clone simon-fred/dotfiles-omarchy ~/Projects/dotfiles-omarchy
cd ~/Projects/dotfiles-omarchy
./install.sh
```

Om `gh` inte är inloggat: `git clone https://github.com/simon-fred/dotfiles-omarchy ~/Projects/dotfiles-omarchy` fungerar lika bra.

`install.sh` kan också köras direkt via curl|bash — då klonar den repot till `~/Projects/dotfiles-omarchy/` själv:

```sh
curl -fsSL https://raw.githubusercontent.com/simon-fred/dotfiles-omarchy/main/install.sh | bash
```

## Köra igen

Idempotent. Filer som redan är korrekt länkade skippas, regular files backupas innan symlink skapas.

## Lägga till en ny fil

1. Flytta filen in i `home/<samma path som under $HOME>`.
2. Lägg till relativa pathen i `FILES`-arrayn i `install.sh`.
3. Kör `./install.sh`.

## Backups

Vid första körningen flyttas befintliga filer till `<fil>.backup.<timestamp>` bredvid originalet. Återställ med `mv <fil>.backup.<timestamp> <fil>` (ta först bort symlinken).

## Yoga Pro 9 ljudfix

Körs **inte** av `install.sh`. Manuell installation:

```sh
sudo ./yoga-pro-9-audio-fix/install.sh
```

Se [`yoga-pro-9-audio-fix/README.md`](yoga-pro-9-audio-fix/README.md) för detaljer (DMI-sanity-check, suspend-handling, avinstallation).

## Avinstallera en fil

```sh
rm ~/.config/hypr/monitors.conf            # ta bort symlinken
mv ~/.config/hypr/monitors.conf.backup.*   # återställ från backup om så önskas
```
