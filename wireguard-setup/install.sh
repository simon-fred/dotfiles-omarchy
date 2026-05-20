#!/usr/bin/env bash
#
# install.sh — Installerar WireGuard + waybar-toggle på Omarchy
#
# Användning:
#   sudo ./install.sh [path/till/config.conf]   # installera (default: ~/Downloads/WCG-Simon.conf)
#   sudo ./install.sh --uninstall               # ta bort allt som installerades (paket lämnas kvar)
#
# Idempotent: kan köras om utan att förstöra något. Patchen av waybar-config:en
# är särskilt viktig att köra om efter `omarchy refresh waybar` som annars
# skriver över config.jsonc med temats default.
set -euo pipefail

# ---------------------------------------------------------------------------
# Färger och loggning
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
IF_NAME="WCG-Simon"
WG_CONFIG="/etc/wireguard/${IF_NAME}.conf"
SUDOERS_FILE="/etc/sudoers.d/wireguard-toggle"
TOGGLE_BIN="/usr/local/bin/wg-toggle"
STATUS_BIN="/usr/local/bin/wg-status"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Root-check (auto-sudo)
# ---------------------------------------------------------------------------
if [[ "${EUID}" -ne 0 ]]; then
    exec sudo --preserve-env=PATH "$0" "$@"
fi

# När vi körts med sudo är $SUDO_USER originalanvändaren.
TARGET_USER="${SUDO_USER:-}"
if [[ -z "$TARGET_USER" ]] || [[ "$TARGET_USER" == "root" ]]; then
    err "Kunde inte avgöra originalanvändaren. Kör inte detta script direkt som root."
    err "Använd: sudo ./install.sh (från en vanlig användares shell)."
    exit 1
fi
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
if [[ -z "$TARGET_HOME" ]] || [[ ! -d "$TARGET_HOME" ]]; then
    err "Kunde inte hitta hem-katalogen för $TARGET_USER."
    exit 1
fi
WAYBAR_CONFIG="$TARGET_HOME/.config/waybar/config.jsonc"

# ---------------------------------------------------------------------------
# Hjälpare för waybar-patch (jq-baserad, idempotent)
# ---------------------------------------------------------------------------
waybar_patch() {
    # Lägger till custom/wireguard i modules-right + modul-definitionen.
    # Idempotent: om båda redan finns blir det en no-op.
    local module_fragment="$SCRIPT_DIR/waybar-module.json"
    if [[ ! -f "$WAYBAR_CONFIG" ]]; then
        warn "Hittar inte $WAYBAR_CONFIG — hoppar över waybar-patch."
        return 0
    fi
    if [[ ! -f "$module_fragment" ]]; then
        err "Saknar $module_fragment"
        return 1
    fi

    local has_in_right has_definition
    has_in_right=$(jq '."modules-right" | index("custom/wireguard") != null' "$WAYBAR_CONFIG")
    has_definition=$(jq 'has("custom/wireguard")' "$WAYBAR_CONFIG")

    if [[ "$has_in_right" == "true" ]] && [[ "$has_definition" == "true" ]]; then
        ok "Waybar redan patchad — modulen finns"
        return 0
    fi

    local tmp
    tmp=$(mktemp)
    # Slå ihop: lägg till i modules-right efter "network" om saknas, och
    # merga modul-definitionen från fragment-filen.
    jq --slurpfile frag "$module_fragment" '
        (if (."modules-right" | index("custom/wireguard")) then .
         else
            ."modules-right" |= (
                if index("network") then
                    . as $a | (index("network") + 1) as $i
                    | $a[:$i] + ["custom/wireguard"] + $a[$i:]
                else
                    . + ["custom/wireguard"]
                end
            )
         end)
        | . + ($frag[0])
    ' "$WAYBAR_CONFIG" > "$tmp"

    # Validera att resultatet är giltig JSON innan vi byter
    if ! jq -e . "$tmp" >/dev/null 2>&1; then
        err "jq-patchen producerade ogiltig JSON — avbryter"
        rm -f "$tmp"
        return 1
    fi

    # Behåll ägare/permissions
    chown "$TARGET_USER:$TARGET_USER" "$tmp"
    chmod 644 "$tmp"
    mv "$tmp" "$WAYBAR_CONFIG"
    ok "Waybar-config patchad: custom/wireguard tillagd"
}

waybar_unpatch() {
    if [[ ! -f "$WAYBAR_CONFIG" ]]; then
        warn "Saknar $WAYBAR_CONFIG — hoppar över waybar-unpatch."
        return 0
    fi
    local has_any
    has_any=$(jq '."modules-right" | index("custom/wireguard") != null or has("custom/wireguard")' "$WAYBAR_CONFIG")
    if [[ "$has_any" != "true" ]]; then
        warn "custom/wireguard fanns inte i waybar-config — inget att rensa"
        return 0
    fi
    local tmp
    tmp=$(mktemp)
    jq '
        ."modules-right" |= map(select(. != "custom/wireguard"))
        | del(."custom/wireguard")
    ' "$WAYBAR_CONFIG" > "$tmp"
    chown "$TARGET_USER:$TARGET_USER" "$tmp"
    chmod 644 "$tmp"
    mv "$tmp" "$WAYBAR_CONFIG"
    ok "custom/wireguard borttagen ur waybar-config"
}

reload_waybar() {
    if pgrep -u "$TARGET_USER" -x waybar >/dev/null 2>&1; then
        sudo -u "$TARGET_USER" pkill -SIGUSR2 waybar 2>/dev/null || true
        ok "Waybar har fått SIGUSR2 (läser om config)"
    else
        warn "Waybar verkar inte köra — hoppar över reload"
    fi
}

# ---------------------------------------------------------------------------
# --uninstall-gren
# ---------------------------------------------------------------------------
if [[ "${1:-}" == "--uninstall" ]]; then
    step "Avinstallerar WireGuard-setup"
    if systemctl is-active --quiet "wg-quick@${IF_NAME}.service"; then
        systemctl stop "wg-quick@${IF_NAME}.service"
        ok "Tunnel ${IF_NAME} stoppad"
    fi
    for f in "$SUDOERS_FILE" "$TOGGLE_BIN" "$STATUS_BIN" "$WG_CONFIG"; do
        if [[ -e "$f" ]]; then
            rm -f "$f"
            ok "Tog bort $f"
        else
            warn "Saknades redan: $f"
        fi
    done
    waybar_unpatch
    reload_waybar
    echo
    step "Klart."
    echo "  Paketen ${C_BOLD}wireguard-tools${C_RESET} och ${C_BOLD}systemd-resolvconf${C_RESET}"
    echo "  lämnades installerade. Ta bort manuellt vid behov:"
    echo "    ${C_BOLD}sudo pacman -R wireguard-tools systemd-resolvconf${C_RESET}"
    exit 0
fi

# ---------------------------------------------------------------------------
# Argument: path till .conf-filen
# ---------------------------------------------------------------------------
SRC_CONFIG="${1:-$TARGET_HOME/Downloads/${IF_NAME}.conf}"

step "Validerar källkonfig"
if [[ ! -f "$SRC_CONFIG" ]]; then
    err "Hittar ingen WireGuard-config på: $SRC_CONFIG"
    err "Ge sökvägen som argument: sudo $0 /path/till/config.conf"
    exit 1
fi
if ! grep -q '^\[Interface\]' "$SRC_CONFIG"; then
    err "$SRC_CONFIG ser inte ut som en WireGuard-config ([Interface]-sektion saknas)"
    exit 1
fi
ok "Källa: $SRC_CONFIG"

# ---------------------------------------------------------------------------
# Installera paket
# ---------------------------------------------------------------------------
step "Installerar paket (wireguard-tools, systemd-resolvconf, jq)"
needed=()
for pkg in wireguard-tools systemd-resolvconf jq; do
    if pacman -Qi "$pkg" >/dev/null 2>&1; then
        ok "$pkg redan installerat"
    else
        needed+=("$pkg")
    fi
done
if [[ ${#needed[@]} -gt 0 ]]; then
    pacman -S --needed --noconfirm "${needed[@]}"
    ok "Installerade: ${needed[*]}"
fi

# ---------------------------------------------------------------------------
# Kopiera config till /etc/wireguard
# ---------------------------------------------------------------------------
step "Kopierar config till $WG_CONFIG"
mkdir -p /etc/wireguard
chmod 700 /etc/wireguard
if [[ -f "$WG_CONFIG" ]] && ! cmp -s "$SRC_CONFIG" "$WG_CONFIG"; then
    ts=$(date +%Y%m%d-%H%M%S)
    cp -a "$WG_CONFIG" "${WG_CONFIG}.backup.${ts}"
    ok "Backupade befintlig config till ${WG_CONFIG}.backup.${ts}"
fi
install -m 600 -o root -g root "$SRC_CONFIG" "$WG_CONFIG"
ok "Config på plats (rw för root, ingen access för andra)"

# ---------------------------------------------------------------------------
# sudoers-regel för NOPASSWD-toggling
# ---------------------------------------------------------------------------
step "Skriver $SUDOERS_FILE"
sudoers_tmp=$(mktemp)
cat > "$sudoers_tmp" <<EOF
# Tillåter %wheel att starta/stoppa wg-quick@${IF_NAME} utan lösenord.
# Används av /usr/local/bin/wg-toggle (waybar custom/wireguard-modulen).
%wheel ALL=(root) NOPASSWD: /usr/bin/systemctl start wg-quick@${IF_NAME}.service, /usr/bin/systemctl stop wg-quick@${IF_NAME}.service
EOF
if ! visudo -cf "$sudoers_tmp" >/dev/null; then
    err "Sudoers-syntaxfel — avbryter (ingen ändring gjord)"
    rm -f "$sudoers_tmp"
    exit 1
fi
install -m 440 -o root -g root "$sudoers_tmp" "$SUDOERS_FILE"
rm -f "$sudoers_tmp"
ok "Sudoers-regel installerad och validerad"

# ---------------------------------------------------------------------------
# Installera toggle- och status-scripten
# ---------------------------------------------------------------------------
step "Installerar $TOGGLE_BIN och $STATUS_BIN"
install -m 755 -o root -g root "$SCRIPT_DIR/wg-toggle.sh" "$TOGGLE_BIN"
install -m 755 -o root -g root "$SCRIPT_DIR/wg-status.sh" "$STATUS_BIN"
ok "Scripten installerade"

# ---------------------------------------------------------------------------
# Patcha waybar
# ---------------------------------------------------------------------------
step "Patchar waybar-config ($WAYBAR_CONFIG)"
waybar_patch
reload_waybar

# ---------------------------------------------------------------------------
# Slutmeddelande
# ---------------------------------------------------------------------------
echo
echo "${C_GREEN}${C_BOLD}Klart!${C_RESET}"
echo
echo "Togglar:"
echo "  ${C_BOLD}Klick på lås-ikonen i waybar${C_RESET} — startar/stoppar tunneln"
echo "  ${C_BOLD}wg-toggle${C_RESET}                       — samma sak från terminalen"
echo
echo "Manuell kontroll:"
echo "  ${C_BOLD}sudo systemctl start  wg-quick@${IF_NAME}${C_RESET}"
echo "  ${C_BOLD}sudo systemctl stop   wg-quick@${IF_NAME}${C_RESET}"
echo "  ${C_BOLD}sudo wg show${C_RESET}                              # status"
echo "  ${C_BOLD}resolvectl status${C_RESET}                         # DNS-status"
echo
echo "${C_YELLOW}OBS:${C_RESET} ${C_BOLD}omarchy refresh waybar${C_RESET} skriver över ~/.config/waybar/config.jsonc"
echo "med temats default. Kör då detta script igen för att re-patcha:"
echo "  ${C_BOLD}sudo $0${C_RESET}"
echo
echo "Avinstallera:"
echo "  ${C_BOLD}sudo $0 --uninstall${C_RESET}"
