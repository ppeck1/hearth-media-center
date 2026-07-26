#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mode="${1:---ci}"
case "${mode}" in
  --ci|--fedora|--hardware) ;;
  *)
    printf 'Usage: %s [--ci|--fedora|--hardware]\n' "$0" >&2
    exit 64
    ;;
esac

if [[ "${mode}" == "--hardware" ]]; then
  printf '%s\n' \
    'Hardware validation is intentionally manual and unclaimed.' \
    'Follow docs/hardware-validation.md on the dedicated Fedora appliance.'
  exit 0
fi

printf 'Hearth verification mode: %s\n' "${mode#--}"
jq -e '.schema_version == 2 and (.items | type == "array")' "${root}/launcher/config/menu.json" >/dev/null
jq -e '.title == "Home"' "${root}/launcher/config/menu.json" >/dev/null
jq -e '
  ([.items[].id] | index("maintenance") | not) and
  ([.items[].id] == ["games", "movies-tv", "settings", "power"]) and
  (.items[] | select(.id == "games") |
    .type == "submenu" and
    ([.children[].id] == ["my-library", "steam"])
  ) and
  (.items[] | select(.id == "settings") |
    .type == "submenu" and
    ([.children[].id] | contains(["controllers-remotes", "desktop-settings"]))
  )
' "${root}/launcher/config/menu.json" >/dev/null
jq -e '.schema_version == 1 and (.families | type == "array") and (.systems | type == "array")' "${root}/launcher/config/system-registry.json" >/dev/null
jq -e '.families | all(has("art") and (.art | type == "string" and length > 0))' "${root}/launcher/config/system-registry.json" >/dev/null
jq -e '.schema_version == 2 and (.profiles | length == 2) and (.device_assignments | type == "array") and ([.profiles[].id] | contains(["ps5", "standard_remote"]))' "${root}/launcher/config/input-profiles-defaults.json" >/dev/null
jq -e '.profiles[] | select(.id == "ps5") | (.bindings.page_left | any(.control == "gamepad_button:left_stick")) and (.bindings.page_right | any(.control == "gamepad_button:right_stick"))' "${root}/launcher/config/input-profiles-defaults.json" >/dev/null
jq -e '.schema_version == 1 and .adapters.steam == "native" and .adapters.retroarch == "native"' "${root}/launcher/config/app-input-policy.json" >/dev/null
jq -e '.schema_version == 1 and .adapters.keyboard_navigation.outputs.home == "bridge:return_to_hearth"' "${root}/launcher/config/input-adapters.json" >/dev/null
jq -e --slurpfile menu "${root}/launcher/config/menu.json" '
  .destinations as $destinations |
  ($menu[0].items[] | select(.id == "movies-tv").children |
    map(select(.type == "command")) |
    all(.id as $id | $destinations | has($id))
  ) and
  ($destinations.plex == "plex")
' "${root}/launcher/config/app-input-policy.json" >/dev/null
for launcher in "${root}"/launchers/*.sh; do
  bash -n "${launcher}"
  test -x "${launcher}"
done
for deployment_script in "${root}"/deploy/fedora/*.sh; do
  bash -n "${deployment_script}"
  test -x "${deployment_script}"
done
test -f "${root}/deploy/fedora/69-hearth-uinput.rules"
test -f "${root}/deploy/fedora/hearth-uinput.conf"
rg -q 'TAG\+="uaccess"' "${root}/deploy/fedora/69-hearth-uinput.rules"
if rg -q -e 'MODE="?0?666' -e 'GROUP="input"' "${root}/deploy/fedora/69-hearth-uinput.rules"; then
  printf '%s\n' 'Unsafe uinput permissions found.' >&2
  exit 1
fi
test -x "${root}/launchers/run-with-input-bridge.sh"
test -x "${root}/launchers/desktop-settings.sh"
for tool in \
  sync-game-artwork.sh \
  install-retroarch-cores.sh \
  install-retroarch-system-assets.sh; do
  test -x "${root}/tools/${tool}"
  bash -n "${root}/tools/${tool}"
done
if rg -q -e '/srv/library' -e 'HEARTH_ROM_ROOT' -e 'thumbnails\.libretro\.com' "${root}/tools/sync-game-artwork.sh"; then
  printf '%s\n' 'Artwork sync must not inspect the ROM library or make per-title thumbnail requests.' >&2
  exit 1
fi
rg -q 'DisplayServer.window_is_focused' "${root}/launcher/scripts/main.gd"
rg -q 'NOTIFICATION_APPLICATION_FOCUS_IN' "${root}/launcher/scripts/main.gd"
rg -q 'caption.*game_title' "${root}/launcher/scripts/main.gd"
rg -q 'retroarch.*thumbnails' "${root}/launcher/scripts/main.gd"
rg -q 'func _find_folder_art' "${root}/launcher/scripts/main.gd"
rg -q 'func _find_folder_wallpaper' "${root}/launcher/scripts/main.gd"
rg -q 'core_options' "${root}/launcher/config/system-registry.json"
if "${root}/launchers/retroarch-game.sh" nestopia_libretro.so /nonexistent invalid-mode >/dev/null 2>&1; then
  printf '%s\n' 'RetroArch launcher accepted an invalid display mode.' >&2
  exit 1
fi
rg -q 'run-with-input-bridge.sh.*destination_id' "${root}/launchers/browser-service.sh"
rg -q -- '--enable-spatial-navigation' "${root}/launchers/browser-service.sh"
rg -q -- '--load-extension=' "${root}/launchers/browser-service.sh"
jq -e '.manifest_version == 3 and (.content_scripts[0].matches == ["https://www.netflix.com/*"])' "${root}/browser_extension/manifest.json" >/dev/null
if command -v node >/dev/null 2>&1; then
  node --check "${root}/browser_extension/netflix-navigation.js"
fi
rg -q 'browser-service.sh prime-video .* prime$' "${root}/launchers/prime-video.sh"
rg -q 'run-with-input-bridge.sh plex' "${root}/launchers/plex-htpc.sh"
for module in \
  scripts/input/input_actions.gd \
  scripts/input/input_event_codec.gd \
  scripts/input/input_profile_store.gd \
  scripts/input/input_manager.gd \
  scripts/settings/input_settings.gd \
  scenes/settings/input_settings.tscn \
  scripts/settings/streaming_service_store.gd \
  scripts/settings/streaming_services.gd \
  scenes/settings/streaming_services.tscn \
  scripts/settings/library_settings_store.gd \
  scripts/settings/library_settings.gd \
  scenes/settings/library_settings.tscn \
  scripts/diagnostics/health_report.gd \
  scripts/diagnostics/system_health.gd \
  scenes/diagnostics/system_health.tscn \
  tests/library_smoke.gd \
  tests/library_browser_smoke.gd \
  tests/library_settings_smoke.gd \
  tests/menu_smoke.gd \
  tests/input_smoke.gd \
  tests/system_health_smoke.gd; do
  test -f "${root}/launcher/${module}"
done
for module in evdev_source.py uinput_sink.py process_runner.py; do
  test -f "${root}/input_bridge/hearth_input_bridge/${module}"
done
test -f "${root}/input_bridge/tests/test_linux_runtime.py"
python3 -m compileall -q "${root}/input_bridge"
PYTHONPATH="${root}" python3 -m unittest discover -s "${root}/input_bridge/tests"
PYTHONPATH="${root}" python3 -m unittest discover -s "${root}/deploy/fedora/tests"
godot_bin="${HEARTH_GODOT:-}"
if [[ -z "${godot_bin}" ]] && command -v godot >/dev/null 2>&1; then
  godot_bin="$(command -v godot)"
fi
if [[ -z "${godot_bin}" && "${mode}" == "--fedora" && -x /opt/hearth/runtime/godot ]]; then
  godot_bin="/opt/hearth/runtime/godot"
fi
if [[ -z "${godot_bin}" || ! -x "${godot_bin}" ]]; then
  printf '%s\n' \
    'Godot 4 is required for verification.' \
    'Set HEARTH_GODOT=/path/to/godot, add godot to PATH, or use --fedora with /opt/hearth/runtime/godot.' >&2
  exit 1
fi
"${godot_bin}" --headless --path "${root}/launcher" --import
for smoke_test in \
  menu_smoke.gd \
  input_smoke.gd \
  library_smoke.gd \
  library_browser_smoke.gd \
  library_settings_smoke.gd \
  system_health_smoke.gd \
  activity_store_smoke.gd; do
  "${godot_bin}" --headless --path "${root}/launcher" --script "res://tests/${smoke_test}"
done
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
absolute_home_marker="/h""ome/"
if rg -n -i -e "${absolute_home_marker}" -e 'C:[\\]Users[\\]' -e 'BEGIN [A-Z ]*PRIVATE KEY' -e '\bsk-[A-Za-z0-9_-]{20,}\b' "${root}" --glob '!.git/**' --glob '!launcher/.godot/**'; then
  printf '%s\n' 'Personal information marker found.' >&2
  exit 1
fi
python3 "${root}/verify/check_repository.py"
if command -v shellcheck >/dev/null 2>&1; then
  mapfile -d '' shell_scripts < <(git -C "${root}" ls-files -z '*.sh')
  shellcheck "${shell_scripts[@]/#/${root}/}"
fi
if [[ "${mode}" == "--fedora" ]]; then
  "${root}/deploy/fedora/doctor.sh"
fi
printf '%s\n' 'Static verification passed.'
