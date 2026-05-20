# WireGuard-setup

Installerar WireGuard på Omarchy och exponerar en klickbar lås-ikon i waybar för
att starta/stoppa tunneln. Tänkt för en enstaka peer (default: `WCG-Simon`) med
en `.conf`-fil som ligger någonstans utanför repot.

Privata nyckeln i `.conf`-filen versioneras **inte** i detta repo. Den kopieras
in i `/etc/wireguard/` av `install.sh` och stannar där.

## Vad paketet gör

`install.sh` är idempotent och utför:

1. Validerar att källkonfigen finns och innehåller `[Interface]`.
2. Installerar paket via pacman (om de saknas):
   - `wireguard-tools` — `wg`, `wg-quick`, systemd-unit-template
   - `systemd-resolvconf` — `resolvconf`-shim som matar `DNS = …`-raden in i den
     redan aktiva `systemd-resolved` (annars failar `wg-quick` på den raden)
   - `jq` — används för att idempotent patcha waybar-config:en
3. Kopierar `~/Downloads/WCG-Simon.conf` (eller path som första argument) till
   `/etc/wireguard/WCG-Simon.conf` med ägare `root:root` och mode `600`.
   Befintlig fil som skiljer sig backupas till `WCG-Simon.conf.backup.<ts>`.
4. Installerar `/etc/sudoers.d/wireguard-toggle` som ger `%wheel` NOPASSWD på
   `systemctl start/stop wg-quick@WCG-Simon.service` (validerat med
   `visudo -cf` innan flytt på plats).
5. Installerar `/usr/local/bin/wg-toggle` (togglar tunneln) och
   `/usr/local/bin/wg-status` (JSON-status för waybar).
6. Patchar `~/.config/waybar/config.jsonc` via `jq` så att `custom/wireguard`
   läggs in efter `network` i `modules-right` och modul-definitionen mergas in.
   Idempotent — kör om utan biverkning.
7. `pkill -SIGUSR2 waybar` så ikonen visas direkt.

## Installation

```bash
sudo ./install.sh
```

Eller med en annan config-path:

```bash
sudo ./install.sh ~/path/till/min-wg.conf
```

(Skriptet sudo:ar om sig självt om du glömmer.)

## Användning efteråt

- **Klick på lås-ikonen i waybar** togglar tunneln. En notification (mako) syns.
- **`wg-toggle`** i terminalen gör samma sak.
- Manuellt: `sudo systemctl start|stop wg-quick@WCG-Simon`.
- Status: `sudo wg show`, `resolvectl status` (visar att 192.168.8.1 sätts som
  DNS för WireGuard-interfacet när tunneln är uppe).

## Viktigt: `omarchy refresh waybar` skriver över din config

`~/.config/waybar/config.jsonc` är en vanlig fil — inte en symlink från detta
repo — och `omarchy refresh waybar` (samt vissa tema-byten) ersätter den med
temats default. Då försvinner `custom/wireguard`-modulen.

Kör då bara om installern:

```bash
sudo ./install.sh
```

Det är en no-op för paket, config-filen och scripten — bara waybar-patchen
körs om.

## Avinstallation

```bash
sudo ./install.sh --uninstall
```

Tar bort sudoers-regeln, toggle-/status-scripten, `/etc/wireguard/WCG-Simon.conf`
och `custom/wireguard` ur waybar-config:en. Paketen (`wireguard-tools`,
`systemd-resolvconf`, `jq`) lämnas installerade — ta bort manuellt med
`sudo pacman -R …` om du vill.

## Säkerhetsnoteringar

- Sudoers-regeln är **snäv**: endast exakta strängarna
  `systemctl start wg-quick@WCG-Simon.service` respektive
  `… stop …` tillåts utan lösen. Inga wildcards.
- Configen i `/etc/wireguard/` är `chmod 600 root:root` — bara root kan läsa
  privata nyckeln.
- `wg-toggle` körs som vanlig användare; bara `sudo systemctl …`-anropet
  eskalerar via NOPASSWD-regeln.
