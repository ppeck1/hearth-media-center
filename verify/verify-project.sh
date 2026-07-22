#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
jq -e '.schema_version == 2 and (.items | type == "array")' "${root}/launcher/config/menu.json" >/dev/null
jq -e '.schema_version == 1 and (.families | type == "array") and (.systems | type == "array")' "${root}/launcher/config/system-registry.json" >/dev/null
jq -e '.families | all(has("art") and (.art | type == "string" and length > 0))' "${root}/launcher/config/system-registry.json" >/dev/null
jq -e '.schema_version == 2 and (.profiles | length == 2) and (.device_assignments | type == "array") and ([.profiles[].id] | contains(["ps5", "standard_remote"]))' "${root}/launcher/config/input-profiles-defaults.json" >/dev/null
jq -e '.schema_version == 1 and .adapters.steam == "native" and .adapters.retroarch == "native"' "${root}/launcher/config/app-input-policy.json" >/dev/null
jq -e '.schema_version == 1 and .adapters.keyboard_navigation.outputs.home == "bridge:return_to_hearth"' "${root}/launcher/config/input-adapters.json" >/dev/null
for launcher in "${root}"/launchers/*.sh; do
  bash -n "${launcher}"
  test -x "${launcher}"
done
for module in \
  scripts/input/input_actions.gd \
  scripts/input/input_event_codec.gd \
  scripts/input/input_profile_store.gd \
  scripts/input/input_manager.gd \
  scripts/settings/input_settings.gd \
  scenes/settings/input_settings.tscn \
  tests/input_smoke.gd; do
  test -f "${root}/launcher/${module}"
done
PYTHONPATH="${root}" python3 -m unittest discover -s "${root}/input_bridge/tests"
if command -v godot >/dev/null 2>&1; then
  godot --headless --path "${root}/launcher" --import
  godot --headless --path "${root}/launcher" --script res://tests/input_smoke.gd
fi
test -f "${root}/launcher/assets/backgrounds/arcade-living-room-v3.png"
while IFS= read -r art_path; do
  test -f "${root}/launcher/${art_path#res://}"
done < <(jq -r '.. | objects | .art? // empty' "${root}/launcher/config/menu.json" "${root}/launcher/config/system-registry.json")
if rg -n -e '<image' -e 'data:image' "${root}/launcher/assets/logos/"*'-panel-v1.svg'; then
  printf '%s\n' 'Raster content found in a streaming panel.' >&2
  exit 1
fi
home_marker="/home""/p""a""u""l"
name_marker="p""a""u""l"
account_marker="p""p""e""c""k""1"
absolute_home_marker="/h""ome/"
if rg -n -i -e "${home_marker}" -e "\\b${name_marker}\\b" -e "${account_marker}" -e "${absolute_home_marker}" "${root}" --glob '!.git/**' --glob '!launcher/.godot/**'; then
  printf '%s\n' 'Personal information marker found.' >&2
  exit 1
fi
printf '%s\n' 'Static verification passed.'
