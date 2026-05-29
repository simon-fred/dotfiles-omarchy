#!/usr/bin/env bash
# Installerar webapps, paket och Node-toolchain som jag använder.
# Idempotent: redan-installerade saker skippas tyst.
set -euo pipefail

# Webapps: "Namn|URL|Ikon" — tom ikon = favicon-fallback via Google s2.
# Namnet blir filnamn i ~/.local/share/applications/<Namn>.desktop.
WEBAPPS=(
  "Teams|https://teams.cloud.microsoft/|"
  "Outlook|https://outlook.office.com/mail/?deeplink=mail%2F|"
  "Slack|https://app.slack.com/client/T042JUS8Y8K/C042XLXLW57|"
  "Google Meet|https://meet.google.com/landing?pli=1|"
)

# Native pacman-paket. dotnet kommer från mise — lämnas utkommenterat.
PACKAGES=(
  alsa-firmware
  sof-firmware
  azure-cli
  bitwarden
  bun
  cloudflared
  tmux
  tmuxp
  # dotnet-sdk
)

# AUR-paket — `omarchy pkg add` använder pacman och hittar inte AUR-paket,
# så de måste gå via `omarchy pkg aur add` (yay/paru under huven).
AUR_PACKAGES=(
  bruno-bin
)

command -v omarchy >/dev/null || { echo "✗ omarchy saknas — kör inte detta på en non-omarchy-maskin" >&2; exit 1; }

# --- Browser: Zen som default --------------------------------------------------
# PWA-arna nedan körs ändå i Chromium (omarchy-launch-webapp faller tillbaka när
# default-browsern inte är en känd Chromium-fork), så screensharing/notifs funkar.
if [[ -f /usr/share/applications/zen.desktop ]] || pacman -Q zen-browser-bin >/dev/null 2>&1; then
  echo "= Zen redan installerad"
else
  echo "- installerar Zen via omarchy"
  omarchy install browser zen
fi

current_browser="$(omarchy default-browser 2>/dev/null || true)"
if [[ "$current_browser" == "zen" ]]; then
  echo "= Zen redan default browser"
else
  echo "- sätter Zen som default browser (var: ${current_browser:-okänd})"
  omarchy default-browser zen
fi

# --- Webapps -------------------------------------------------------------------
skipped_webapps=0
installed_webapps=0
for entry in "${WEBAPPS[@]}"; do
  IFS='|' read -r name url icon <<< "$entry"
  if [[ -f "$HOME/.local/share/applications/${name}.desktop" ]]; then
    echo "= webapp redan installerad: $name"
    skipped_webapps=$((skipped_webapps+1))
  else
    echo "- installerar webapp: $name"
    omarchy webapp install "$name" "$url" "$icon"
    installed_webapps=$((installed_webapps+1))
  fi
done

# --- Pacman-paket --------------------------------------------------------------
# omarchy pkg add är själv idempotent (installerar bara saknade), men vi
# rapporterar ändå för symmetri med uninstall-skriptet.
skipped_pkgs=0
to_add=()
for pkg in "${PACKAGES[@]}"; do
  if pacman -Q "$pkg" >/dev/null 2>&1; then
    echo "= paket redan installerat: $pkg"
    skipped_pkgs=$((skipped_pkgs+1))
  else
    to_add+=("$pkg")
  fi
done

added_pkgs=0
if [[ ${#to_add[@]} -gt 0 ]]; then
  echo "- installerar paket: ${to_add[*]}"
  omarchy pkg add "${to_add[@]}"
  added_pkgs=${#to_add[@]}
fi

# --- AUR-paket -----------------------------------------------------------------
# Installerade AUR-paket dyker upp i pacman-DB:n, så `pacman -Q` funkar som
# idempotens-check även här.
skipped_aur=0
to_add_aur=()
for pkg in "${AUR_PACKAGES[@]}"; do
  if pacman -Q "$pkg" >/dev/null 2>&1; then
    echo "= AUR-paket redan installerat: $pkg"
    skipped_aur=$((skipped_aur+1))
  else
    to_add_aur+=("$pkg")
  fi
done

added_aur=0
if [[ ${#to_add_aur[@]} -gt 0 ]]; then
  echo "- installerar AUR-paket: ${to_add_aur[*]}"
  omarchy pkg aur add "${to_add_aur[@]}"
  added_aur=${#to_add_aur[@]}
fi

# --- Node LTS + pnpm via nvm ---------------------------------------------------
# nvm sätter PATH/funktioner i ett enda skal — subshell så vi inte muterar
# anropande shell.
node_status="skipped"
pnpm_status="skipped"
if [[ -r /usr/share/nvm/init-nvm.sh ]]; then
  output="$(bash <<'NVMEOF'
set -e
# shellcheck disable=SC1091
source /usr/share/nvm/init-nvm.sh
if ! nvm alias default 2>/dev/null | grep -q "lts/"; then
  echo "INSTALLED_NODE"
  nvm install --lts >/dev/null
  nvm alias default "lts/*" >/dev/null
else
  echo "SKIPPED_NODE"
fi
if ! command -v pnpm >/dev/null; then
  echo "INSTALLED_PNPM"
  npm install -g pnpm >/dev/null
else
  echo "SKIPPED_PNPM:$(pnpm --version)"
fi
NVMEOF
)"
  if grep -q "INSTALLED_NODE" <<<"$output"; then
    echo "- installerade Node LTS via nvm"
    node_status="installed"
  else
    echo "= Node LTS redan default"
  fi
  if grep -q "INSTALLED_PNPM" <<<"$output"; then
    echo "- installerade pnpm globalt"
    pnpm_status="installed"
  else
    pnpm_version="$(grep "SKIPPED_PNPM" <<<"$output" | cut -d: -f2 || true)"
    echo "= pnpm redan installerat${pnpm_version:+ (v$pnpm_version)}"
  fi
else
  echo "✗ /usr/share/nvm/init-nvm.sh saknas — installera nvm via pacman först" >&2
fi

# --- Summary -------------------------------------------------------------------
echo
echo "Summary: $installed_webapps webapps installerade ($skipped_webapps redan där), $added_pkgs paket installerade ($skipped_pkgs redan där), $added_aur AUR-paket installerade ($skipped_aur redan där), node=$node_status, pnpm=$pnpm_status."
