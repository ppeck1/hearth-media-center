#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
registry_path="${repo_root}/launcher/config/system-registry.json"
config_root="${XDG_CONFIG_HOME:-${HOME}/.config}"
user_core_root="${config_root}/retroarch/cores"
system_core_root="/usr/lib64/libretro"
buildbot_root="https://buildbot.libretro.com/nightly/linux/x86_64/latest"
staging_root="$(mktemp -d)"
trap 'rm -rf -- "${staging_root}"' EXIT

for dependency in jq curl unzip readelf nm ldd install; do
  if ! command -v "${dependency}" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "${dependency}" >&2
    exit 2
  fi
done

mkdir -p "${user_core_root}"

validate_core() {
  local core_path="$1"
  local dependency_report
  readelf -h "${core_path}" >/dev/null
  nm -D "${core_path}" |
    awk '$NF == "retro_init" { found = 1 } END { exit found ? 0 : 1 }'
  dependency_report="$(ldd "${core_path}" 2>&1)"
  if grep -q 'not found' <<<"${dependency_report}"; then
    printf 'Core has an unresolved shared-library dependency: %s\n' "${core_path}" >&2
    printf '%s\n' "${dependency_report}" >&2
    return 1
  fi
}

installed=0
existing=0
while IFS= read -r core_file; do
  if [[ -s "${user_core_root}/${core_file}" ]]; then
    validate_core "${user_core_root}/${core_file}"
    printf 'Ready (user): %s\n' "${core_file}"
    existing=$((existing + 1))
    continue
  fi
  if [[ -s "${system_core_root}/${core_file}" ]]; then
    validate_core "${system_core_root}/${core_file}"
    printf 'Ready (system): %s\n' "${core_file}"
    existing=$((existing + 1))
    continue
  fi

  archive_path="${staging_root}/${core_file}.zip"
  extracted_path="${staging_root}/${core_file}"
  printf 'Downloading generic core: %s\n' "${core_file}"
  curl --fail --location --retry 3 --connect-timeout 10 \
    "${buildbot_root}/${core_file}.zip" --output "${archive_path}"
  archive_entry_count="$(
    unzip -Z1 "${archive_path}" |
      awk -v expected="${core_file}" '$0 == expected { count += 1 } END { print count + 0 }'
  )"
  if [[ "${archive_entry_count}" != "1" ]]; then
    printf 'Core archive did not contain exactly %s\n' "${core_file}" >&2
    exit 3
  fi
  unzip -p "${archive_path}" "${core_file}" >"${extracted_path}"
  validate_core "${extracted_path}"
  install -m 0755 "${extracted_path}" "${user_core_root}/${core_file}"
  printf 'Installed: %s\n' "${core_file}"
  installed=$((installed + 1))
done < <(jq -r '.systems[].core' "${registry_path}" | sort -u)

printf 'RetroArch core coverage complete: %d installed, %d already ready.\n' \
  "${installed}" "${existing}"
