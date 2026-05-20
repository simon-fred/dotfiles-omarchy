#!/usr/bin/env bash
# wg-status — JSON-status för waybar (custom/wireguard-modulen).
# Installeras av wireguard-setup/install.sh till /usr/local/bin/wg-status.

IF=WCG-Simon
UNIT="wg-quick@${IF}.service"

if systemctl is-active --quiet "$UNIT"; then
    printf '{"text":"󰦝","tooltip":"WireGuard %s: connected","class":"connected","alt":"connected"}\n' "$IF"
else
    printf '{"text":"󰦞","tooltip":"WireGuard %s: disconnected","class":"disconnected","alt":"disconnected"}\n' "$IF"
fi
