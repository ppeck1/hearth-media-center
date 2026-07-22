#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
jq -e '.schema_version == 2 and (.items | type == "array")' "${root}/launcher/config/menu.json" >/dev/null
jq -e '.schema_version == 1 and (.extensions | type == "object")' "${root}/launcher/config/library-profiles.json" >/dev/null
bash -n "${root}/launchers/retroarch-game.sh"
test -x "${root}/launchers/retroarch-game.sh"
test -f "${root}/launcher/assets/backgrounds/arcade-living-room-v1.png"
home_marker="/home""/p""a""u""l"
name_marker="p""a""u""l"
if rg -n -i -e "${home_marker}" -e "\\b${name_marker}\\b" "${root}" --glob '!.git/**' --glob '!launcher/.godot/**'; then
  printf '%s\n' 'Personal information marker found.' >&2
  exit 1
fi
printf '%s\n' 'Static verification passed.'
