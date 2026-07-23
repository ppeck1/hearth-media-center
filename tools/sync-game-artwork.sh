#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
registry_path="${repo_root}/launcher/config/system-registry.json"
data_root="${XDG_DATA_HOME:-${HOME}/.local/share}"
pack_root="${HEARTH_ARTWORK_PACK_ROOT:-${data_root}/hearth/artwork-packs}"
github_root="https://github.com/libretro-thumbnails"

for dependency in jq git; do
  if ! command -v "${dependency}" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "${dependency}" >&2
    exit 2
  fi
done

usage() {
  cat <<'EOF'
Usage:
  sync-game-artwork.sh --list
  sync-game-artwork.sh SYSTEM_ID [SYSTEM_ID ...]

Downloads complete Named_Boxarts folders for the requested systems. It never
reads the ROM library and never sends ROM filenames or game titles to a server.
The remote service learns only which generic system artwork packs were chosen.
EOF
}

if [[ "$#" -eq 0 ]]; then
  usage
  exit 64
fi

if [[ "$1" == "--list" ]]; then
  jq -r '.systems[] | select(.thumbnail_db or .thumbnail_dbs) |
    "\(.id)\t\((.thumbnail_dbs // [.thumbnail_db]) | join(", "))"' "${registry_path}"
  exit 0
fi

declare -A selected_databases=()
for system_id in "$@"; do
  if ! jq -e --arg id "${system_id}" '.systems[] | select(.id == $id)' "${registry_path}" >/dev/null; then
    printf 'Unknown system id: %s\n' "${system_id}" >&2
    exit 64
  fi
  while IFS= read -r database_name; do
    [[ -n "${database_name}" ]] && selected_databases["${database_name}"]=1
  done < <(
    jq -r --arg id "${system_id}" \
      '.systems[] | select(.id == $id) |
       (.thumbnail_dbs // (if .thumbnail_db then [.thumbnail_db] else [] end))[]' \
      "${registry_path}"
  )
done

if (( ${#selected_databases[@]} == 0 )); then
  printf 'None of the selected systems has an artwork pack mapping.\n' >&2
  exit 65
fi

mkdir -p "${pack_root}"
for database_name in "${!selected_databases[@]}"; do
  repository_name="${database_name// /_}"
  destination="${pack_root}/${repository_name}"
  source_url="${github_root}/${repository_name}.git"
  if [[ -d "${destination}/.git" ]]; then
    printf 'Updating complete %s box-art pack...\n' "${database_name}"
    git -C "${destination}" sparse-checkout set Named_Boxarts
    git -C "${destination}" pull --ff-only
  elif [[ -e "${destination}" ]]; then
    printf 'Destination exists but is not a managed artwork pack: %s\n' "${destination}" >&2
    exit 66
  else
    printf 'Downloading complete %s box-art pack...\n' "${database_name}"
    git clone --depth 1 --filter=blob:none --sparse "${source_url}" "${destination}"
    git -C "${destination}" sparse-checkout set Named_Boxarts
  fi
done

printf 'Artwork packs are ready under %s.\n' "${pack_root}"
