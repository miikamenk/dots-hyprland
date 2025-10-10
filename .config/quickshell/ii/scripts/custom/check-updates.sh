#!/usr/bin/bash

if [ "${1-}" = "--up" ]; then
  # Adjust to your preferred AUR helper (yay/paru)
  AUR_HELPER=""
  if command -v yay >/dev/null 2>&1; then AUR_HELPER="yay -Syu --noconfirm"; fi
  if command -v paru >/dev/null 2>&1; then AUR_HELPER="paru -Syu --noconfirm"; fi

  # Update pacman (will prompt for sudo)
  if command -v pacman >/dev/null 2>&1; then
    echo "Running: sudo pacman -Syu"
    sudo pacman -Syu
  fi

  # Update AUR helper (if any) - some users prefer to run it manually; keep it optional
  if [ -n "$AUR_HELPER" ]; then
    echo "Running: $AUR_HELPER"
    # Run without --noconfirm if you prefer prompts; change as desired
    $AUR_HELPER || true
  fi

  # Update flatpak
  if command -v flatpak >/dev/null 2>&1; then
    echo "Running: flatpak update -y"
    flatpak update -y || true
  fi

  echo "All done."
  exit 0
fi

# count pacman updates
pacman_count=0
if command -v checkupdates >/dev/null 2>&1; then
  # checkupdates prints one package per line
  pacman_count=$(checkupdates 2>/dev/null | wc -l | tr -d ' ')
else
  # fallback: pacman -Qu might work but is less portable; try it
  if pacman -Qu >/dev/null 2>&1; then
    pacman_count=$(pacman -Qu 2>/dev/null | wc -l | tr -d ' ')
  fi
fi

# count AUR updates using yay (yay -Qua prints lines for aur updates)
aur_count=0
if command -v yay >/dev/null 2>&1; then
  aur_count=$(yay -Qua 2>/dev/null | wc -l | tr -d ' ')
else
  # optionally try paru as alternative
  if command -v paru >/dev/null 2>&1; then
    aur_count=$(paru -Qua 2>/dev/null | wc -l | tr -d ' ')
  fi
fi

# count flatpak updates
# Different flatpak versions produce different dry-run outputs.
# This tries 'flatpak update --assumeno --noninteractive --dry-run' and counts non-empty lines.
flatpak_count=0
if command -v flatpak >/dev/null 2>&1; then
  # attempt common dry-run; sanitize blank lines and informational lines
  flat_out=$(flatpak update --assumeno --noninteractive --dry-run 2>/dev/null || true)
  # If output contains lines with "Updating" or package ids, count non-empty useful lines:
  # Remove lines that are obviously non-package messages (like 'Nothing to do')
  flatpkgs=$(printf "%s\n" "$flat_out" | sed '/^\s*$/d' | sed '/Nothing to do/d' | sed '/^Updating/d' | sed '/^Info:/d')
  # If the sanitized output is empty but "Updating" lines existed, count those
  if [ -n "$flatpkgs" ]; then
    flatpak_count=$(printf "%s\n" "$flatpkgs" | wc -l | tr -d ' ')
  else
    # try counting "Updating" lines as fallback
    upd_lines=$(printf "%s\n" "$flat_out" | grep -E -c 'Updating|^Id:|^org\.' || true)
    flatpak_count=${upd_lines:-0}
  fi
fi

# Print JSON single-line (easy to parse from QML)
printf '{"pacman":%d,"aur":%d,"flatpak":%d}\n' "$pacman_count" "$aur_count" "$flatpak_count"
