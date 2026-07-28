#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/fedora/lib.sh
source "${script_dir}/lib.sh"

source_root="$(hearth_repo_root)"
install_root="${HEARTH_INSTALL_ROOT:-/opt/hearth}"
library_root="${HEARTH_LIBRARY_ROOT:-/srv/library}"
etc_root="${HEARTH_ETC_ROOT:-/etc}"
godot_request=""
HEARTH_DRY_RUN="${HEARTH_DRY_RUN:-0}"

usage() {
  printf 'Usage: %s [--dry-run] [--source PATH] [--godot PATH]\n' "$0"
}

while (( $# > 0 )); do
  case "$1" in
    --dry-run) HEARTH_DRY_RUN=1; shift ;;
    --source) source_root="$(readlink -f "${2:?--source requires a path}")"; shift 2 ;;
    --godot) godot_request="$(readlink -f "${2:?--godot requires a path}")"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 64 ;;
  esac
done
export HEARTH_DRY_RUN

hearth_validate_roots "${install_root}" "${library_root}"
hearth_require_fedora
hearth_session_report
hearth_require_root_for_changes

target_user="$(hearth_detect_user)"
target_home="$(hearth_user_home "${target_user}")"
target_uid="$(id -u "${target_user}")"
target_gid="$(id -g "${target_user}")"
[[ -n "${target_home}" ]] || { printf 'Could not determine home for %s.\n' "${target_user}" >&2; exit 1; }

required_commands=(bash git install python3 realpath systemctl)
optional_commands=(flatpak google-chrome-stable chromium retroarch steam zenity)
missing_required=()
for command_name in "${required_commands[@]}"; do
  command -v "${command_name}" >/dev/null 2>&1 || missing_required+=("${command_name}")
done
if (( ${#missing_required[@]} > 0 )); then
  printf 'Missing required commands: %s\n' "${missing_required[*]}" >&2
  exit 1
fi
printf 'Required commands: PASS\n'
for command_name in "${optional_commands[@]}"; do
  if command -v "${command_name}" >/dev/null 2>&1; then
    printf 'Optional dependency: %-24s available\n' "${command_name}"
  else
    printf 'Optional dependency: %-24s not installed\n' "${command_name}"
  fi
done

godot_source="$(hearth_find_godot "${godot_request}")" || {
  printf '%s\n' \
    'Godot 4 was not found. Install Godot, or rerun with --godot /absolute/path/to/godot.' >&2
  exit 1
}
printf 'Godot runtime: %s\n' "${godot_source}"

if [[ -e "${install_root}" ]]; then
  printf 'An installation already exists at %s; use update.sh.\n' "${install_root}" >&2
  exit 1
fi

staging="${install_root}.staging.$$"
trap 'if [[ "${HEARTH_DRY_RUN:-0}" != "1" && -d "${staging:-}" ]]; then find "${staging}" -depth -delete; fi' EXIT
hearth_run install -d -m 0755 "${staging}"
hearth_copy_tracked_tree "${source_root}" "${staging}"
hearth_run install -D -m 0755 "${godot_source}" "${staging}/runtime/godot"
hearth_import_godot_project "${staging}/runtime/godot" "${staging}/launcher"
if [[ "${HEARTH_TEST_MODE:-0}" != "1" ]]; then
  hearth_run chown -R root:root "${staging}"
fi
hearth_run mv "${staging}" "${install_root}"

hearth_run install -d -o "${target_uid}" -g "${target_gid}" -m 0755 \
  "${library_root}" \
  "${library_root}/games" \
  "${library_root}/games/roms" \
  "${library_root}/games/pc"

if [[ "${HEARTH_TEST_MODE:-0}" == "1" ]]; then
  hearth_run install -D -m 0644 \
    "${source_root}/deploy/fedora/69-hearth-uinput.rules" \
    "${etc_root}/udev/rules.d/69-hearth-uinput.rules"
  hearth_run install -D -m 0644 \
    "${source_root}/deploy/fedora/hearth-uinput.conf" \
    "${etc_root}/modules-load.d/hearth-uinput.conf"
else
  hearth_run install -D -o root -g root -m 0644 \
    "${source_root}/deploy/fedora/69-hearth-uinput.rules" \
    "${etc_root}/udev/rules.d/69-hearth-uinput.rules"
  hearth_run install -D -o root -g root -m 0644 \
    "${source_root}/deploy/fedora/hearth-uinput.conf" \
    "${etc_root}/modules-load.d/hearth-uinput.conf"
fi
if [[ "${HEARTH_DRY_RUN}" != "1" && "${HEARTH_TEST_MODE:-0}" != "1" ]]; then
  modprobe uinput
  udevadm control --reload-rules
  udevadm trigger --subsystem-match=misc --sysname-match=uinput --action=add
fi

service_dir="${target_home}/.config/systemd/user"
hearth_run install -D -o "${target_uid}" -g "${target_gid}" -m 0644 \
  "${source_root}/deploy/fedora/hearth.service" \
  "${service_dir}/hearth.service"
hearth_enable_user_service "${target_user}" "${target_uid}"

printf '\nInstallation report\n'
printf '  Hearth files:       %s\n' "${install_root}"
printf '  Personal library:   %s (preserved on update and uninstall)\n' "${library_root}"
printf '  Local settings:     %s (not modified)\n' "${target_home}/.config/hearth"
printf '  Browser profiles:   %s (not modified)\n' "${target_home}/.config/media-kiosk"
printf '  Input bridge user:  %s (never root)\n' "${target_user}"
if [[ "${HEARTH_DRY_RUN}" != "1" ]]; then
  if [[ -r /dev/uinput && -w /dev/uinput ]]; then
    printf '  /dev/uinput:        accessible in this session\n'
  else
    printf '  /dev/uinput:        log out and back in before validating access\n'
  fi
fi
printf '\nNext steps\n'
printf '  1. Log out and back in as %s so the uinput ACL is refreshed.\n' "${target_user}"
printf '  2. Run: %s/deploy/fedora/doctor.sh\n' "${install_root}"
printf '  3. Add only personal content under %s; do not copy it into the repository.\n' "${library_root}"
printf '  4. Follow docs/hardware-validation.md before calling the appliance validated.\n'
