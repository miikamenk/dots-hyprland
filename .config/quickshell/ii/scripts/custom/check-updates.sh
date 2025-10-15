#!/usr/bin/env bash

# Check release
if [ ! -f /etc/arch-release ]; then
  exit 0
fi

fpk_exup="pkg_installed flatpak && flatpak update"
temp_file="$XDG_RUNTIME_DIR/update_info"
[ -f "$temp_file" ] && source "$temp_file"

pkg_installed() {
  local pkgIn=$1
  if command -v "${pkgIn}" &>/dev/null; then
    return 0
  elif command -v "flatpak" &>/dev/null && flatpak info "${pkgIn}" &>/dev/null; then
    return 0
  else
    return 1
  fi
}

get_aurhlpr() {
  if pkg_installed yay; then
    aurhlpr="yay"
  elif pkg_installed paru; then
    # shellcheck disable=SC2034
    aurhlpr="paru"
  fi
}

get_aurhlpr

# Trigger upgrade
if [ "$1" == "up" ]; then
  if [ -f "$temp_file" ]; then
    # Read info from env file
    while IFS="=" read -r key value; do
      case "$key" in
      OFFICIAL_UPDATES) pacman=$value ;;
      AUR_UPDATES) aur=$value ;;
      FLATPAK_UPDATES) flatpak=$value ;;
      esac
    done <"$temp_file"

    command="
        printf '[Pacman] %-10s\n[AUR]      %-10s\n[Flatpak]  %-10s\n' '$pacman' '$aur' '$flatpak'
        "${aurhlpr}" -Syu
        $fpk_exup
        read -n 1 -p 'Press any key to continue...'
        "
    kitty --title systemupdate "$SHELL" -ic "${command}"

  else
    echo "No upgrade info found. Please run the script without parameters first."
  fi
  exit 0
fi

# Check for AUR updates
aur=$(${aurhlpr} -Qua | wc -l)
ofc=$(
  temp_db=$(mktemp -u "${XDG_RUNTIME_DIR:-"/tmp"}/checkupdates_db_XXXXXX")
  trap '[ -f "$temp_db" ] && rm "$temp_db" 2>/dev/null' EXIT INT TERM
  CHECKUPDATES_DB="$temp_db" checkupdates 2>/dev/null | wc -l
)

# Check for flatpak updates
if pkg_installed flatpak; then
  fpk=$(flatpak remote-ls --updates | wc -l)
  fpk_disp="\n󰏓 Flatpak $fpk"
else
  fpk=0
  fpk_disp=""
fi

# Calculate total available updates
upd=$((ofc + aur + fpk))
# Prepare the upgrade info
upgrade_info=$(
  cat <<EOF
OFFICIAL_UPDATES=$ofc
AUR_UPDATES=$aur
FLATPAK_UPDATES=$fpk
EOF
)

# Save the upgrade info
echo "$upgrade_info" >"$temp_file"
# Show tooltip
if [ $upd -eq 0 ]; then
  upd="" #Remove Icon completely
  # upd="󰮯"   #If zero Display Icon only

  printf '{"pacman":0,"aur":0,"flatpak":0}\n'
else
  printf '{"pacman":%d,"aur":%d,"flatpak":%d}\n' "$ofc" "$aur" "$fpk"
fi
