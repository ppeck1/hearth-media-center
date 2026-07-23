#!/usr/bin/env bash
set -euo pipefail

if (( EUID != 0 )); then
  echo "Run this one-time setup with sudo." >&2
  exit 2
fi

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
source_rule="$(dirname "${script_path}")/69-hearth-uinput.rules"
target_rule="/etc/udev/rules.d/69-hearth-uinput.rules"
modules_source="$(dirname "${script_path}")/hearth-uinput.conf"
modules_target="/etc/modules-load.d/hearth-uinput.conf"

install -o root -g root -m 0644 "${source_rule}" "${target_rule}"
install -o root -g root -m 0644 "${modules_source}" "${modules_target}"
modprobe uinput
udevadm control --reload-rules
udevadm trigger --subsystem-match=misc --sysname-match=uinput --action=add

echo "Installed ${target_rule}. Log out and back in, then run the Hearth input probe as the media user."
