#!/usr/bin/env bash
# wg-toggle — togglar WireGuard-tunneln WCG-Simon på/av.
# Eskalerar via sudo NOPASSWD-regel i /etc/sudoers.d/wireguard-toggle.
# Installeras av wireguard-setup/install.sh till /usr/local/bin/wg-toggle.
set -e

IF=WCG-Simon
UNIT="wg-quick@${IF}.service"

if systemctl is-active --quiet "$UNIT"; then
    sudo systemctl stop "$UNIT"
    notify-send -u low "WireGuard" "Tunnel ${IF} stoppad"
else
    sudo systemctl start "$UNIT"
    notify-send -u low "WireGuard" "Tunnel ${IF} startad"
fi

pkill -SIGUSR2 waybar 2>/dev/null || true
