#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/fedora/lib.sh
source "${script_dir}/lib.sh"

install_root="${HEARTH_INSTALL_ROOT:-/opt/hearth}"
library_root="${HEARTH_LIBRARY_ROOT:-/srv/library}"
etc_root="${HEARTH_ETC_ROOT:-/etc}"
HEARTH_DRY_RUN="${HEARTH_DRY_RUN:-0}"
remove_settings=0

while (( $# > 0 )); do
  case "$1" in
    --dry-run) HEARTH_DRY_RUN=1; shift ;;
    --remove-settings) remove_settings=1; shift ;;
    --help|-h) printf 'Usage: %s [--dry-run] [--remove-settings]\n' "$0"; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; exit 64 ;;
  esac
done
export HEARTH_DRY_RUN

hearth_validate_roots "${install_root}" "${library_root}"
hearth_require_root_for_changes
target_user="$(hearth_detect_user)"
target_home="$(hearth_user_home "${target_user}")"
target_uid="$(id -u "${target_user}")"
service_path="${target_home}/.config/systemd/user/hearth.service"

if [[ "${HEARTH_DRY_RUN}" != "1" && "${HEARTH_TEST_MODE:-0}" != "1" && -d "/run/user/${target_uid}" ]]; then
  runuser -u "${target_user}" -- env XDG_RUNTIME_DIR="/run/user/${target_uid}" \
    systemctl --user disable --now hearth.service 2>/dev/null || true
fi
if [[ -e "${install_root}" ]]; then
  hearth_run find "${install_root}" -xdev -depth -delete
else
  printf 'Hearth application directory is already absent: %s\n' "${install_root}"
fi
hearth_run rm -f \
  "${etc_root}/udev/rules.d/69-hearth-uinput.rules" \
  "${etc_root}/modules-load.d/hearth-uinput.conf" \
  "${service_path}"

if (( remove_settings == 1 )); then
  settings_root="${target_home}/.config/hearth"
  case "${settings_root}" in
    */.config/hearth) [[ ! -e "${settings_root}" ]] || hearth_run find "${settings_root}" -xdev -depth -delete ;;
    *) printf 'Refusing unexpected settings path: %s\n' "${settings_root}" >&2; exit 1 ;;
  esac
fi

printf 'Removed Hearth application files and its user service.\n'
printf 'Preserved personal library: %s\n' "${library_root}"
printf 'Preserved browser profiles: %s\n' "${target_home}/.config/media-kiosk"
if (( remove_settings == 0 )); then
  printf 'Preserved Hearth settings: %s\n' "${target_home}/.config/hearth"
else
  printf 'Removed Hearth settings by explicit request.\n'
fi
printf 'Backups under %s-backups were preserved for manual review.\n' "${install_root}"
