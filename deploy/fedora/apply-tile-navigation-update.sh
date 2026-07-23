#!/usr/bin/env bash
set -euo pipefail

if (( EUID != 0 )); then
  echo "Run this update with sudo." >&2
  exit 2
fi

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
repo_root="$(cd "$(dirname "${script_path}")/../.." && pwd)"
hearth_root="/opt/hearth"
extension_source="${repo_root}/browser_extension"
extension_target="${hearth_root}/browser_extension"

for source_path in \
  "${extension_source}/manifest.json" \
  "${extension_source}/netflix-navigation.js" \
  "${extension_source}/netflix-navigation.css" \
  "${repo_root}/launchers/browser-service.sh" \
  "${repo_root}/launcher/config/input-profiles-defaults.json" \
  "${repo_root}/input_bridge/hearth_input_bridge/evdev_source.py" \
  "${repo_root}/input_bridge/hearth_input_bridge/process_runner.py" \
  "${repo_root}/input_bridge/tests/test_bridge.py" \
  "${repo_root}/input_bridge/tests/test_linux_runtime.py"; do
  test -f "${source_path}"
done

for target_path in \
  "${hearth_root}/launchers/browser-service.sh" \
  "${hearth_root}/launcher/config/input-profiles-defaults.json" \
  "${hearth_root}/input_bridge/hearth_input_bridge/evdev_source.py" \
  "${hearth_root}/input_bridge/hearth_input_bridge/process_runner.py" \
  "${hearth_root}/input_bridge/tests/test_bridge.py" \
  "${hearth_root}/input_bridge/tests/test_linux_runtime.py"; do
  test -f "${target_path}"
  backup_path="${target_path}.pre-tile-navigation"
  if [[ ! -e "${backup_path}" ]]; then
    cp -a "${target_path}" "${backup_path}"
  fi
done

install -d -o root -g root -m 0755 "${extension_target}"
install -o root -g root -m 0644 "${extension_source}/manifest.json" "${extension_target}/manifest.json"
install -o root -g root -m 0644 "${extension_source}/netflix-navigation.js" "${extension_target}/netflix-navigation.js"
install -o root -g root -m 0644 "${extension_source}/netflix-navigation.css" "${extension_target}/netflix-navigation.css"
install -o root -g root -m 0755 "${repo_root}/launchers/browser-service.sh" "${hearth_root}/launchers/browser-service.sh"
install -o root -g root -m 0644 \
  "${repo_root}/launcher/config/input-profiles-defaults.json" \
  "${hearth_root}/launcher/config/input-profiles-defaults.json"
install -o root -g root -m 0644 \
  "${repo_root}/input_bridge/hearth_input_bridge/evdev_source.py" \
  "${hearth_root}/input_bridge/hearth_input_bridge/evdev_source.py"
install -o root -g root -m 0644 \
  "${repo_root}/input_bridge/hearth_input_bridge/process_runner.py" \
  "${hearth_root}/input_bridge/hearth_input_bridge/process_runner.py"
install -o root -g root -m 0644 \
  "${repo_root}/input_bridge/tests/test_bridge.py" \
  "${hearth_root}/input_bridge/tests/test_bridge.py"
install -o root -g root -m 0644 \
  "${repo_root}/input_bridge/tests/test_linux_runtime.py" \
  "${hearth_root}/input_bridge/tests/test_linux_runtime.py"

echo "Installed Hearth Netflix tile navigation and controller failsafe update."
