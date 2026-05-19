#!/usr/bin/env bash
# Avinstallerar förinställda Omarchy-appar som jag inte använder.
# Idempotent: appar som redan är borta skippas tyst.
set -euo pipefail

# Omarchy-webapps (PWA:er). Listade utan ".desktop"-suffix — exakt så som
# omarchy-webapp-install namnger dem i ~/.local/share/applications/.
WEBAPPS=(
  Basecamp
  Figma
  Fizzy
  "Google Contacts"
  "Google Maps"
  "Google Messages"
  "Google Photos"
  HEY
  WhatsApp
  X
  Zoom
)

# Native pacman-paket.
PACKAGES=(
  signal-desktop
  typora
)

command -v omarchy >/dev/null || { echo "✗ omarchy saknas — kör inte detta på en non-omarchy-maskin" >&2; exit 1; }

# Webapps batchas i ett enda anrop — annars startar walker om N gånger och
# triggar systemds rate-limit på app-walker@autostart.service.
skipped_webapps=0
to_remove=()
for name in "${WEBAPPS[@]}"; do
  if [[ -f "$HOME/.local/share/applications/${name}.desktop" ]]; then
    to_remove+=("$name")
  else
    echo "= webapp redan borta: $name"
    skipped_webapps=$((skipped_webapps+1))
  fi
done

removed_webapps=0
if [[ ${#to_remove[@]} -gt 0 ]]; then
  echo "- tar bort webapps: ${to_remove[*]}"
  omarchy webapp remove "${to_remove[@]}"
  removed_webapps=${#to_remove[@]}
fi

skipped_pkgs=0
to_drop=()
for pkg in "${PACKAGES[@]}"; do
  if pacman -Q "$pkg" >/dev/null 2>&1; then
    to_drop+=("$pkg")
  else
    echo "= paket redan borta: $pkg"
    skipped_pkgs=$((skipped_pkgs+1))
  fi
done

removed_pkgs=0
if [[ ${#to_drop[@]} -gt 0 ]]; then
  echo "- tar bort paket: ${to_drop[*]}"
  omarchy pkg drop "${to_drop[@]}"
  removed_pkgs=${#to_drop[@]}
fi

echo
echo "Summary: $removed_webapps webapps borttagna ($skipped_webapps redan borta), $removed_pkgs paket borttagna ($skipped_pkgs redan borta)."
