#!/usr/bin/env bash
#
# install.sh — Aktivera alla högtalare på Lenovo Yoga Pro 9 16IMH9 (Gen 9)
#
# Baserat på community-fixet från:
#   https://github.com/maximmaxim345/yoga_pro_9i_gen9_linux
#
# Användning:
#   sudo ./install.sh             # installera + aktivera
#   sudo ./install.sh --uninstall # ta bort allt som installerades
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Färgar och loggning
# ---------------------------------------------------------------------------
if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && [[ "${TERM:-}" != "dumb" ]]; then
    C_RESET=$(tput sgr0); C_RED=$(tput setaf 1); C_GREEN=$(tput setaf 2)
    C_YELLOW=$(tput setaf 3); C_BLUE=$(tput setaf 4); C_BOLD=$(tput bold)
else
    C_RESET=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""; C_BOLD=""
fi
step() { echo "${C_BLUE}${C_BOLD}==>${C_RESET} $*"; }
ok()   { echo "  ${C_GREEN}✓${C_RESET} $*"; }
warn() { echo "  ${C_YELLOW}!${C_RESET} $*"; }
err()  { echo "${C_RED}${C_BOLD}✗${C_RESET} $*" >&2; }

# ---------------------------------------------------------------------------
# Konstanter
# ---------------------------------------------------------------------------
# DMI product_name är Lenovo's typkod (inte den läsbara modellsträngen).
# Stödda modeller (samma I2C-fix från upstream-skriptet):
#   83BY = Yoga Pro 9 16IRP8 (Gen 8)
#   83DN = Yoga Pro 9 16IMH9 (Gen 9)  ← primärmålet för detta paket
#   83L0 = Yoga Pro 9 16IAH10 (Gen 10)
SUPPORTED_TYPE_CODES=("83BY" "83DN" "83L0")
SCRIPT_PATH="/usr/local/bin/2pa-byps.sh"
SERVICE_PATH="/etc/systemd/system/yoga-16imh9-speakers.service"
MODPROBE_PATH="/etc/modprobe.d/yoga-speakers.conf"
SERVICE_NAME="yoga-16imh9-speakers.service"

# ---------------------------------------------------------------------------
# Root-check (auto-sudo)
# ---------------------------------------------------------------------------
if [[ "${EUID}" -ne 0 ]]; then
    exec sudo --preserve-env=PATH "$0" "$@"
fi

# ---------------------------------------------------------------------------
# Uninstall
# ---------------------------------------------------------------------------
if [[ "${1:-}" == "--uninstall" ]]; then
    step "Avinstallerar Yoga Pro 9 högtalar-fix"
    if systemctl is-enabled --quiet "$SERVICE_NAME" 2>/dev/null; then
        systemctl disable --now "$SERVICE_NAME"
        ok "Service inaktiverad och stoppad"
    else
        warn "Service var inte aktiverad — hoppar över"
    fi
    for f in "$SERVICE_PATH" "$MODPROBE_PATH" "$SCRIPT_PATH"; do
        if [[ -e "$f" ]]; then
            rm -f "$f"
            ok "Tog bort $f"
        else
            warn "Saknades redan: $f"
        fi
    done
    systemctl daemon-reload
    ok "systemd reloadad"
    echo
    step "Klart. Reboota för att kärnan ska sluta ladda blacklistad modul igen."
    exit 0
fi

# ---------------------------------------------------------------------------
# Sanity-check: rätt laptop-modell?
# ---------------------------------------------------------------------------
step "Kontrollerar laptop-modell"
type_code=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "okänd")
friendly_name=$(cat /sys/class/dmi/id/product_version 2>/dev/null || echo "okänd")
supported=0
for code in "${SUPPORTED_TYPE_CODES[@]}"; do
    [[ "$type_code" == "$code" ]] && supported=1 && break
done
if [[ $supported -ne 1 ]]; then
    err "Den här installern stödjer endast Lenovo Yoga Pro 9-serien."
    err "Stödda DMI-typkoder: ${SUPPORTED_TYPE_CODES[*]}"
    err "Den här datorn rapporterar: typkod='$type_code', modell='$friendly_name'"
    err "Avbryter för att inte skriva fel I2C-register till okänd hårdvara."
    exit 1
fi
ok "Modell: $friendly_name (typkod $type_code)"

# ---------------------------------------------------------------------------
# Installera i2c-tools
# ---------------------------------------------------------------------------
step "Installerar i2c-tools (om saknas)"
if pacman -Qi i2c-tools >/dev/null 2>&1; then
    ok "i2c-tools redan installerat"
else
    pacman -S --needed --noconfirm i2c-tools
    ok "i2c-tools installerat"
fi

# ---------------------------------------------------------------------------
# Skriv ut 2pa-byps.sh (skriptet som talar med amparna via I2C)
# ---------------------------------------------------------------------------
# Källa: https://github.com/maximmaxim345/yoga_pro_9i_gen9_linux (README, juli 2025)
# Stödjer Gen 8 (16IRP8), Gen 9 (16IMH9), Gen 10 (16IAH10) med autodetektering.
step "Skriver $SCRIPT_PATH"
cat > "$SCRIPT_PATH" <<'PAYLOAD_EOF'
#!/bin/bash
# 2pa-byps.sh — slår på högtalarförstärkarna via I2C
# Upstream: https://github.com/maximmaxim345/yoga_pro_9i_gen9_linux
# DO NOT EDIT — hanteras av install.sh

export TERM=linux
# Some distros don't have i2c-dev module loaded by default, so we load it manually
modprobe i2c-dev

laptop_model=$(</sys/class/dmi/id/product_name)
echo "Laptop model: $laptop_model"

# Function to find the correct I2C bus
find_i2c_bus() {
    local adapter_description="Synopsys DesignWare I2C adapter"
    local dw_count=$(i2cdetect -l | grep -c "$adapter_description")

    # Use 2nd adapter for 16IAH10 (Gen 10), 3rd for others
    local bus_index=3
    [[ "$laptop_model" == "83L0" ]] && bus_index=2

    if [ "$dw_count" -lt "$bus_index" ]; then
        echo "Error: Less than $bus_index DesignWare I2C adapters found." >&2
        return 1
    fi
    local bus_number=$(i2cdetect -l | grep "$adapter_description" | awk '{print $1}' | sed 's/i2c-//' | sed -n "${bus_index}p")
    echo "$bus_number"
}
i2c_bus=$(find_i2c_bus)
if [ -z "$i2c_bus" ]; then
    echo "Error: Could not find the DesignWare I2C bus for the audio IC." >&2
    exit 1
fi
echo "Using I2C bus: $i2c_bus"

if [[ "$laptop_model" == "83BY" ]]; then
    # For the 16IRP8 (see issue #17)
    i2c_addr=(0x39 0x38 0x3d 0x3b)
else
    i2c_addr=(0x3f 0x38)
fi

count=0
for value in "${i2c_addr[@]}"; do
    val=$((count % 2))
    i2cset -f -y "$i2c_bus" "$value" 0x00 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x7f 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x01 0x01
    i2cset -f -y "$i2c_bus" "$value" 0x0e 0xc4
    i2cset -f -y "$i2c_bus" "$value" 0x0f 0x40
    i2cset -f -y "$i2c_bus" "$value" 0x5c 0xd9
    i2cset -f -y "$i2c_bus" "$value" 0x60 0x10
    if [ $val -eq 0 ]; then
        i2cset -f -y "$i2c_bus" "$value" 0x0a 0x1e
    else
        i2cset -f -y "$i2c_bus" "$value" 0x0a 0x2e
    fi
    i2cset -f -y "$i2c_bus" "$value" 0x0d 0x01
    i2cset -f -y "$i2c_bus" "$value" 0x16 0x40
    i2cset -f -y "$i2c_bus" "$value" 0x00 0x01
    i2cset -f -y "$i2c_bus" "$value" 0x17 0xc8
    i2cset -f -y "$i2c_bus" "$value" 0x00 0x04
    i2cset -f -y "$i2c_bus" "$value" 0x30 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x31 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x32 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x33 0x01

    i2cset -f -y "$i2c_bus" "$value" 0x00 0x08
    i2cset -f -y "$i2c_bus" "$value" 0x18 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x19 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x1a 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x1b 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x28 0x40
    i2cset -f -y "$i2c_bus" "$value" 0x29 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x2a 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x2b 0x00

    i2cset -f -y "$i2c_bus" "$value" 0x00 0x0a
    i2cset -f -y "$i2c_bus" "$value" 0x48 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x49 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x4a 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x4b 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x58 0x40
    i2cset -f -y "$i2c_bus" "$value" 0x59 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x5a 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x5b 0x00

    i2cset -f -y "$i2c_bus" "$value" 0x00 0x00
    i2cset -f -y "$i2c_bus" "$value" 0x02 0x00
    count=$((count + 1))
done
PAYLOAD_EOF
chmod +x "$SCRIPT_PATH"
ok "Skript installerat och körbart"

# ---------------------------------------------------------------------------
# Skriv systemd-service
# ---------------------------------------------------------------------------
step "Skriver $SERVICE_PATH"
cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=Turn on Yoga Pro 9 speakers via I2C
After=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target

[Service]
User=root
Type=oneshot
ExecStart=/bin/sh -c "$SCRIPT_PATH | logger"

[Install]
WantedBy=multi-user.target sleep.target
Also=suspend.target hibernate.target hybrid-sleep.target suspend-then-hibernate.target
EOF
ok "Service-fil skriven"

# ---------------------------------------------------------------------------
# Blacklista kärnans amp-modul (annars konkurrerar den med vårt skript)
# ---------------------------------------------------------------------------
step "Skriver $MODPROBE_PATH"
cat > "$MODPROBE_PATH" <<'EOF'
# Yoga Pro 9 16IMH9 — blacklist Texas Instruments amp-modul.
# Vi konfigurerar amparna direkt via I2C i 2pa-byps.sh istället för att låta
# kärnans driver göra det (den misslyckas på denna SSID i nuvarande kärnor).
blacklist snd_hda_scodec_tas2781_i2c
EOF
ok "modprobe-blacklist skriven"

# Ta bort ev. äldre udev-regel från tidigare workaround-försök
if [[ -e /etc/udev/rules.d/99-i2c-power-control.rules ]]; then
    rm -f /etc/udev/rules.d/99-i2c-power-control.rules
    ok "Tog bort gammal udev-regel 99-i2c-power-control.rules"
fi

# ---------------------------------------------------------------------------
# Aktivera service
# ---------------------------------------------------------------------------
step "Aktiverar systemd-service"
systemctl daemon-reload
systemctl enable --now "$SERVICE_NAME"
ok "Service aktiverad och startad"

# ---------------------------------------------------------------------------
# Smoke-test
# ---------------------------------------------------------------------------
step "Kör skriptet manuellt en gång (smoke-test)"
if "$SCRIPT_PATH" 2>&1 | sed 's/^/    /'; then
    ok "Skriptet körde utan fel"
else
    err "Skriptet returnerade fel — kolla utskriften ovan"
    exit 1
fi

step "Kontrollerar service-status"
if systemctl is-active --quiet "$SERVICE_NAME" || \
   systemctl show -p ActiveState "$SERVICE_NAME" | grep -q 'ActiveState=active'; then
    ok "Service är aktiv"
else
    # oneshot-services hamnar i 'inactive' efter att ha kört klart, det är OK
    state=$(systemctl show -p ActiveState --value "$SERVICE_NAME")
    result=$(systemctl show -p Result --value "$SERVICE_NAME")
    if [[ "$result" == "success" ]]; then
        ok "Service kördes klart (ActiveState=$state, Result=success)"
    else
        warn "Service status oklart: ActiveState=$state Result=$result"
    fi
fi

# ---------------------------------------------------------------------------
# Slutmeddelande
# ---------------------------------------------------------------------------
echo
echo "${C_GREEN}${C_BOLD}Klart!${C_RESET}"
echo
echo "Testa ljudet nu:"
echo "  ${C_BOLD}speaker-test -c 2 -t wav -l 1${C_RESET}"
echo "eller spela en låt med tydlig bas. Du ska nu höra fylligt ljud, inte bara"
echo "diskant."
echo
echo "Servicen körs om automatiskt vid boot och efter suspend/resume."
echo
echo "För att avinstallera senare:"
echo "  ${C_BOLD}sudo $0 --uninstall${C_RESET}"
