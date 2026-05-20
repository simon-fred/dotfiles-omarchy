#!/usr/bin/env bash
#
# install.sh — UVC-bandbreddsfix för USB-webcams som visar statiskt brus.
#
# Bakgrund:
#   Vissa USB UVC-webcams (t.ex. Logitech C270, 046d:0825 i en dock) rapporterar
#   fel bandbreddsdescriptor och ger då bara myror i bilden istället för video.
#   Kärnans UVC_QUIRK_FIX_BANDWIDTH (värde 128) tvingar uvcvideo att räkna ut
#   bandbredden från format och framerate istället för att lita på enheten.
#
# Användning:
#   sudo ./install.sh             # installera + ladda om modulen
#   sudo ./install.sh --uninstall # ta bort konfigurationen
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
MODPROBE_PATH="/etc/modprobe.d/uvcvideo-quirks.conf"
QUIRK_VALUE=128  # UVC_QUIRK_FIX_BANDWIDTH

# ---------------------------------------------------------------------------
# Root-check (auto-sudo)
# ---------------------------------------------------------------------------
if [[ "${EUID}" -ne 0 ]]; then
    exec sudo --preserve-env=PATH "$0" "$@"
fi

reload_uvcvideo() {
    # Tar emot ev. extra modprobe-args (t.ex. "quirks=128") för att garantera
    # att rätt parametrar appliceras även om någon udev-trigger råkar ladda
    # modulen mellan vår rmmod och modprobe.
    local args=("$@")
    step "Laddar om uvcvideo-modulen"
    if lsmod | grep -q '^uvcvideo'; then
        # Stoppa allt som håller i modulen först — annars kan rmmod misslyckas.
        if ! modprobe -r uvcvideo 2>/dev/null; then
            warn "modprobe -r uvcvideo misslyckades — något använder kameran just nu."
            warn "Stäng webbläsare/kamera-appar och kör skriptet igen, eller reboota."
            return 1
        fi
        ok "uvcvideo avladdad"
    else
        warn "uvcvideo var inte laddad"
    fi
    modprobe uvcvideo "${args[@]}"
    if [[ ${#args[@]} -gt 0 ]]; then
        ok "uvcvideo laddad igen med ${args[*]}"
    else
        ok "uvcvideo laddad igen"
    fi
}

# ---------------------------------------------------------------------------
# Uninstall
# ---------------------------------------------------------------------------
if [[ "${1:-}" == "--uninstall" ]]; then
    step "Avinstallerar UVC-bandbreddsfix"
    if [[ -e "$MODPROBE_PATH" ]]; then
        rm -f "$MODPROBE_PATH"
        ok "Tog bort $MODPROBE_PATH"
    else
        warn "Saknades redan: $MODPROBE_PATH"
    fi
    reload_uvcvideo || warn "Modul-reload misslyckades — reboota för att återställa quirks=0."  # ingen extra arg = återgå till default
    echo
    current=$(cat /sys/module/uvcvideo/parameters/quirks 2>/dev/null || echo "?")
    step "Klart. uvcvideo.quirks är nu: $current"
    exit 0
fi

# ---------------------------------------------------------------------------
# Sanity-check: finns uvcvideo överhuvudtaget?
# ---------------------------------------------------------------------------
step "Kontrollerar att uvcvideo-modulen finns"
if ! modinfo uvcvideo >/dev/null 2>&1; then
    err "uvcvideo-modulen finns inte på systemet — inget att konfigurera."
    exit 1
fi
ok "uvcvideo tillgänglig"

# ---------------------------------------------------------------------------
# Skriv modprobe-konfigen
# ---------------------------------------------------------------------------
step "Skriver $MODPROBE_PATH"
cat > "$MODPROBE_PATH" <<EOF
# USB-webcam i dock (t.ex. Logitech C270, 046d:0825) visar statiskt brus utan
# denna. UVC_QUIRK_FIX_BANDWIDTH ($QUIRK_VALUE) får kärnan att räkna ut
# bandbredden från format/framerate istället för att lita på enhetens
# descriptor. Quirken är global över alla UVC-kameror men godartad för dem
# som inte behöver den.
options uvcvideo quirks=$QUIRK_VALUE
EOF
ok "modprobe-konfiguration skriven"

# ---------------------------------------------------------------------------
# Ladda om modulen så ändringen tar effekt
# ---------------------------------------------------------------------------
if ! reload_uvcvideo "quirks=$QUIRK_VALUE"; then
    warn "Reboota för att aktivera fixen."
    exit 0
fi

# ---------------------------------------------------------------------------
# Verifiera att quirken är satt
# ---------------------------------------------------------------------------
step "Verifierar modulparameter"
current=$(cat /sys/module/uvcvideo/parameters/quirks 2>/dev/null || echo "?")
if [[ "$current" == "$QUIRK_VALUE" ]]; then
    ok "uvcvideo.quirks = $current (FIX_BANDWIDTH aktiv)"
else
    err "uvcvideo.quirks = $current, väntade $QUIRK_VALUE"
    err "Kontrollera $MODPROBE_PATH och kör modprobe -r/modprobe igen, eller reboota."
    exit 1
fi

# ---------------------------------------------------------------------------
# Slutmeddelande
# ---------------------------------------------------------------------------
echo
echo "${C_GREEN}${C_BOLD}Klart!${C_RESET}"
echo
echo "Testa USB-webcamen nu — t.ex. öppna ${C_BOLD}https://webcamtests.com/${C_RESET}"
echo "i Zen/Chromium och välj den externa kameran."
echo
echo "För att avinstallera senare:"
echo "  ${C_BOLD}sudo $0 --uninstall${C_RESET}"
