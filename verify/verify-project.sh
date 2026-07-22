#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
jq -e '.schema_version == 2 and (.items | type == "array")' "${root}/launcher/config/menu.json" >/dev/null
jq -e '.schema_version == 1 and (.families | type == "array") and (.systems | type == "array")' "${root}/launcher/config/system-registry.json" >/dev/null
jq -e '.families | all(has("art") and (.art | type == "string" and length > 0))' "${root}/launcher/config/system-registry.json" >/dev/null
bash -n "${root}/launchers/retroarch-game.sh"
test -x "${root}/launchers/retroarch-game.sh"
test -f "${root}/launcher/assets/backgrounds/arcade-living-room-v2.png"
while IFS= read -r art_path; do
  test -f "${root}/launcher/${art_path#res://}"
done < <(jq -r '.. | objects | .art? // empty' "${root}/launcher/config/menu.json" "${root}/launcher/config/system-registry.json")
home_marker="/home""/p""a""u""l"
name_marker="p""a""u""l"
account_marker="p""p""e""c""k""1"
absolute_home_marker="/h""ome/"
if rg -n -i -e "${home_marker}" -e "\\b${name_marker}\\b" -e "${account_marker}" -e "${absolute_home_marker}" "${root}" --glob '!.git/**' --glob '!launcher/.godot/**'; then
  printf '%s\n' 'Personal information marker found.' >&2
  exit 1
fi
printf '%s\n' 'Static verification passed.'
