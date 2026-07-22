#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
jq -e '.schema_version == 2 and (.items | type == "array")' "${root}/launcher/config/menu.json" >/dev/null
jq -e '.title == "Home"' "${root}/launcher/config/menu.json" >/dev/null
jq -e '.schema_version == 1 and (.families | type == "array") and (.systems | type == "array")' "${root}/launcher/config/system-registry.json" >/dev/null
jq -e '.families | all(has("art") and (.art | type == "string" and length > 0))' "${root}/launcher/config/system-registry.json" >/dev/null
jq -e '.schema_version == 2 and (.profiles | length == 2) and (.device_assignments | type == "array") and ([.profiles[].id] | contains(["ps5", "standard_remote"]))' "${root}/launcher/config/input-profiles-defaults.json" >/dev/null
jq -e '.schema_version == 1 and .adapters.steam == "native" and .adapters.retroarch == "native"' "${root}/launcher/config/app-input-policy.json" >/dev/null
jq -e '.schema_version == 1 and .adapters.keyboard_navigation.outputs.home == "bridge:return_to_hearth"' "${root}/launcher/config/input-adapters.json" >/dev/null
jq -e --slurpfile menu "${root}/launcher/config/menu.json" '
  .destinations as $destinations |
  ($menu[0].items[] | select(.id == "streaming").children | all(.id as $id | $destinations | has($id))) and
  ($destinations.plex == "plex")
' "${root}/launcher/config/app-input-policy.json" >/dev/null
for launcher in "${root}"/launchers/*.sh; do
  bash -n "${launcher}"
  test -x "${launcher}"
done
bash -n "${root}/deploy/fedora/install-input-access.sh"
test -x "${root}/deploy/fedora/install-input-access.sh"
test -f "${root}/deploy/fedora/69-hearth-uinput.rules"
test -f "${root}/deploy/fedora/hearth-uinput.conf"
rg -q 'TAG\+="uaccess"' "${root}/deploy/fedora/69-hearth-uinput.rules"
if rg -q -e 'MODE="?0?666' -e 'GROUP="input"' "${root}/deploy/fedora/69-hearth-uinput.rules"; then
  printf '%s\n' 'Unsafe uinput permissions found.' >&2
  exit 1
fi
test -x "${root}/launchers/run-with-input-bridge.sh"
rg -q 'run-with-input-bridge.sh.*destination_id' "${root}/launchers/browser-service.sh"
rg -q 'browser-service.sh prime-video .* prime$' "${root}/launchers/prime-video.sh"
rg -q 'run-with-input-bridge.sh plex' "${root}/launchers/plex-htpc.sh"
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
for module in evdev_source.py uinput_sink.py process_runner.py; do
  test -f "${root}/input_bridge/hearth_input_bridge/${module}"
done
test -f "${root}/input_bridge/tests/test_linux_runtime.py"
python3 -m compileall -q "${root}/input_bridge"
PYTHONPATH="${root}" python3 -m unittest discover -s "${root}/input_bridge/tests"
if command -v godot >/dev/null 2>&1; then
  godot --headless --path "${root}/launcher" --import
  godot --headless --path "${root}/launcher" --script res://tests/input_smoke.gd
fi
test -f "${root}/launcher/assets/backgrounds/arcade-living-room-v4.png"
rg -q 'res://assets/backgrounds/arcade-living-room-v4.png' "${root}/launcher/scripts/main.gd"
rg -q 'Time.get_time_dict_from_system\(\)' "${root}/launcher/scripts/main.gd"
if rg -q -e 'name_label' -e 'var marquee' -e 'var breadcrumb' -e 'Good evening' "${root}/launcher/scripts/main.gd"; then
  printf '%s\n' 'Legacy carousel/header text remains in main.gd.' >&2
  exit 1
fi
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
