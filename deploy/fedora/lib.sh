#!/usr/bin/env bash
# Shared, non-mutating helpers for the Fedora deployment commands.

hearth_repo_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd
}

hearth_detect_user() {
  if [[ -n "${HEARTH_TARGET_USER:-}" ]]; then
    printf '%s\n' "${HEARTH_TARGET_USER}"
  elif [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
    printf '%s\n' "${SUDO_USER}"
  else
    id -un
  fi
}

hearth_user_home() {
  local user="$1"
  if [[ -n "${HEARTH_TARGET_HOME:-}" ]]; then
    printf '%s\n' "${HEARTH_TARGET_HOME}"
    return
  fi
  getent passwd "${user}" | cut -d: -f6
}

hearth_os_release() {
  printf '%s\n' "${HEARTH_OS_RELEASE:-/etc/os-release}"
}

hearth_require_fedora() {
  local release_file
  release_file="$(hearth_os_release)"
  if [[ ! -r "${release_file}" ]]; then
    printf 'Cannot read operating-system metadata: %s\n' "${release_file}" >&2
    return 1
  fi
  # shellcheck disable=SC1090
  source "${release_file}"
  if [[ "${ID:-}" != "fedora" ]]; then
    printf 'Unsupported operating system: %s. Hearth alpha supports Fedora only.\n' "${PRETTY_NAME:-unknown}" >&2
    return 1
  fi
  printf 'Fedora detected: %s\n' "${PRETTY_NAME:-Fedora ${VERSION_ID:-unknown}}"
}

hearth_session_report() {
  case "${XDG_SESSION_TYPE:-unknown}" in
    wayland) printf '%s\n' 'Session: Wayland' ;;
    x11) printf '%s\n' 'Session: X11 (supported for recovery, not the preferred appliance session)' ;;
    *) printf 'Session: %s (log in graphically before hardware validation)\n' "${XDG_SESSION_TYPE:-unknown}" ;;
  esac
}

hearth_run() {
  if [[ "${HEARTH_DRY_RUN:-0}" == "1" ]]; then
    printf 'DRY RUN:'
    printf ' %q' "$@"
    printf '\n'
    return 0
  fi
  "$@"
}

hearth_require_root_for_changes() {
  if [[ "${HEARTH_DRY_RUN:-0}" == "1" || "${HEARTH_TEST_MODE:-0}" == "1" ]]; then
    return 0
  fi
  if (( EUID != 0 )); then
    printf 'Run this command with sudo (or use --dry-run).\n' >&2
    return 1
  fi
}

hearth_validate_roots() {
  local install_root="$1"
  local library_root="$2"
  case "${install_root}" in
    /opt/hearth|/tmp/hearth-test-*|/var/tmp/hearth-test-*|/tmp/*/hearth-test-*|/var/tmp/*/hearth-test-*) ;;
    *) printf 'Refusing unexpected install root: %s\n' "${install_root}" >&2; return 1 ;;
  esac
  case "${library_root}" in
    /srv/library|/tmp/hearth-library-test-*|/var/tmp/hearth-library-test-*|/tmp/*/hearth-library-test-*|/var/tmp/*/hearth-library-test-*) ;;
    *) printf 'Refusing unexpected library root: %s\n' "${library_root}" >&2; return 1 ;;
  esac
}

hearth_copy_tracked_tree() {
  local source_root="$1"
  local destination="$2"
  local relative
  while IFS= read -r -d '' relative; do
    hearth_run install -D -m 0644 "${source_root}/${relative}" "${destination}/${relative}"
  done < <(git -C "${source_root}" ls-files -z)
  while IFS= read -r -d '' relative; do
    hearth_run chmod 0755 "${destination}/${relative}"
  done < <(git -C "${source_root}" ls-files -z -- '*.sh' 'tools/*.py')
}

hearth_import_godot_project() {
  local godot_runtime="$1"
  local project_root="$2"

  hearth_run "${godot_runtime}" --headless --path "${project_root}" --import
  if [[ "${HEARTH_DRY_RUN:-0}" == "1" ]]; then
    return 0
  fi
  if [[ ! -d "${project_root}/.godot/imported" ]] ||
     ! find "${project_root}/.godot/imported" -type f -print -quit | grep -q .; then
    printf 'Godot did not create the required imported-resource cache in %s.\n' \
      "${project_root}" >&2
    return 1
  fi
}

hearth_find_godot() {
  local requested="${1:-}"
  if [[ -n "${requested}" && -x "${requested}" ]]; then
    readlink -f "${requested}"
  elif command -v godot >/dev/null 2>&1; then
    command -v godot
  elif command -v godot4 >/dev/null 2>&1; then
    command -v godot4
  elif [[ -x /opt/hearth/runtime/godot ]]; then
    printf '%s\n' /opt/hearth/runtime/godot
  else
    return 1
  fi
}

hearth_enable_user_service() {
  local target_user="$1"
  local target_uid="$2"
  if [[ "${HEARTH_DRY_RUN:-0}" == "1" ]]; then
    printf 'DRY RUN: enable systemd user service for %s\n' "${target_user}"
    return 0
  fi
  if [[ "${HEARTH_TEST_MODE:-0}" == "1" || ! -d "/run/user/${target_uid}" ]]; then
    return 0
  fi
  runuser -u "${target_user}" -- env \
    XDG_RUNTIME_DIR="/run/user/${target_uid}" \
    systemctl --user daemon-reload
  runuser -u "${target_user}" -- env \
    XDG_RUNTIME_DIR="/run/user/${target_uid}" \
    systemctl --user enable hearth.service
}
