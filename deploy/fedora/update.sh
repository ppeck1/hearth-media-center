#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/fedora/lib.sh
source "${script_dir}/lib.sh"

source_root="$(hearth_repo_root)"
install_root="${HEARTH_INSTALL_ROOT:-/opt/hearth}"
library_root="${HEARTH_LIBRARY_ROOT:-/srv/library}"
godot_request=""
HEARTH_DRY_RUN="${HEARTH_DRY_RUN:-0}"

while (( $# > 0 )); do
  case "$1" in
    --dry-run) HEARTH_DRY_RUN=1; shift ;;
    --source) source_root="$(readlink -f "${2:?--source requires a path}")"; shift 2 ;;
    --godot) godot_request="$(readlink -f "${2:?--godot requires a path}")"; shift 2 ;;
    --help|-h) printf 'Usage: %s [--dry-run] [--source PATH] [--godot PATH]\n' "$0"; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; exit 64 ;;
  esac
done
export HEARTH_DRY_RUN

hearth_validate_roots "${install_root}" "${library_root}"
hearth_require_fedora
hearth_session_report
hearth_require_root_for_changes
[[ -f "${install_root}/launcher/project.godot" ]] || {
  printf 'No Hearth installation was found at %s. Run install.sh first.\n' "${install_root}" >&2
  exit 1
}

godot_source="$(hearth_find_godot "${godot_request}")" || {
  printf 'Godot runtime not found; pass --godot PATH.\n' >&2
  exit 1
}
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
backup_root="${install_root}-backups/${stamp}"
staging="${install_root}.staging.$$"
previous="${install_root}.previous.$$"
trap 'if [[ "${HEARTH_DRY_RUN:-0}" != "1" && -d "${staging:-}" ]]; then find "${staging}" -depth -delete; fi' EXIT

hearth_run install -d -m 0755 "${staging}"
hearth_copy_tracked_tree "${source_root}" "${staging}"
hearth_run install -D -m 0755 "${godot_source}" "${staging}/runtime/godot"
if [[ "${HEARTH_TEST_MODE:-0}" != "1" ]]; then
  hearth_run chown -R root:root "${staging}"
fi
hearth_run install -d -m 0755 "${backup_root}"
hearth_run cp -a "${install_root}/." "${backup_root}/"

hearth_run mv "${install_root}" "${previous}"
if ! hearth_run mv "${staging}" "${install_root}"; then
  hearth_run mv "${previous}" "${install_root}"
  printf 'Update failed; the previous installation was restored.\n' >&2
  exit 1
fi
hearth_run find "${previous}" -depth -delete

printf 'Update installed successfully.\n'
printf 'Backup: %s\n' "${backup_root}"
printf 'Personal library preserved: %s\n' "${library_root}"
printf 'Local settings and browser profiles were not modified.\n'
printf 'Rollback: systemctl --user stop hearth.service; sudo mv %s %s.failed; sudo cp -a %s %s; systemctl --user start hearth.service\n' \
  "${install_root}" "${install_root}" "${backup_root}" "${install_root}"
if [[ "${HEARTH_DRY_RUN}" != "1" && "${HEARTH_SKIP_DOCTOR:-0}" != "1" ]]; then
  "${install_root}/deploy/fedora/doctor.sh" || {
    printf 'Update completed, but diagnostics found required failures. Use the backup above to roll back.\n' >&2
    exit 1
  }
fi
