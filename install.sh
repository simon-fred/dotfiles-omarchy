#!/usr/bin/env bash
# dotfiles-omarchy installer — symlinka user-editable Omarchy-configs in på systemet.
# Idempotent: backupar befintliga regular files, skippar redan-länkade.
set -euo pipefail

REPO_URL="https://github.com/simon-fred/dotfiles-omarchy.git"
DEFAULT_CLONE_DIR="$HOME/Projects/dotfiles-omarchy"

# NEVER add .config/omarchy/current/* here — det är runtime-state som Omarchy skriver till.
FILES=(
  .bashrc
  .bash_profile
  .config/hypr/monitors.conf
  .config/hypr/input.conf
  .config/hypr/bindings.conf
  .config/hypr/looknfeel.conf
  .config/hypr/autostart.conf
  .config/hypr/hypridle.conf
  .config/omarchy/branding/about.txt
  .config/omarchy/branding/screensaver.txt
  .config/omarchy/extensions/menu.sh
)

timestamp="$(date +%Y%m%d-%H%M%S)"

resolve_repo_dir() {
  local script_path script_dir
  script_path="${BASH_SOURCE[0]:-}"
  if [[ -n "$script_path" && -f "$script_path" ]]; then
    script_dir="$(cd "$(dirname "$script_path")" && pwd)"
    if [[ -d "$script_dir/home" ]]; then
      echo "$script_dir"
      return
    fi
  fi
  # Curl|bash-läge: klona eller pull:a.
  if [[ -d "$DEFAULT_CLONE_DIR/.git" ]]; then
    echo "→ uppdaterar $DEFAULT_CLONE_DIR" >&2
    git -C "$DEFAULT_CLONE_DIR" pull --ff-only >&2
  else
    echo "→ klonar $REPO_URL till $DEFAULT_CLONE_DIR" >&2
    mkdir -p "$(dirname "$DEFAULT_CLONE_DIR")"
    git clone "$REPO_URL" "$DEFAULT_CLONE_DIR" >&2
  fi
  echo "$DEFAULT_CLONE_DIR"
}

REPO_DIR="$(resolve_repo_dir)"

if [[ ! -d "$HOME/.local/share/omarchy" ]]; then
  echo "✗ Detta ser inte ut som en Omarchy-installation (saknar ~/.local/share/omarchy)." >&2
  exit 1
fi

linked=0; skipped=0; backed_up=0

for rel in "${FILES[@]}"; do
  src="$REPO_DIR/home/$rel"
  dst="$HOME/$rel"

  if [[ ! -e "$src" ]]; then
    echo "✗ saknad källa i repot: $src" >&2
    exit 1
  fi

  mkdir -p "$(dirname "$dst")"

  if [[ -L "$dst" ]] && [[ "$(readlink "$dst")" == "$src" ]]; then
    echo "= ok (already linked) $rel"
    skipped=$((skipped+1))
    continue
  fi

  if [[ -e "$dst" || -L "$dst" ]]; then
    mv "$dst" "$dst.backup.$timestamp"
    echo "↳ backup $rel → $rel.backup.$timestamp"
    backed_up=$((backed_up+1))
  fi

  ln -s "$src" "$dst"
  echo "+ linked $rel"
  linked=$((linked+1))
done

echo
echo "Summary: $linked linked, $skipped already-linked, $backed_up backed up."
echo
echo "Yoga Pro 9 ljudfix körs separat:"
echo "  sudo $REPO_DIR/yoga-pro-9-audio-fix/install.sh"
echo
echo "USB-webcam-fix (modprobe-quirk för dock-kamera med myror) körs separat:"
echo "  sudo $REPO_DIR/usb-webcam-bandwidth-fix/install.sh"
echo
echo "WireGuard-setup (paket + /etc/wireguard/-config + waybar-toggle) körs separat:"
echo "  sudo $REPO_DIR/wireguard-setup/install.sh"
