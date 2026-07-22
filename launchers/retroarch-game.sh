#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 2 ]]; then
  printf '%s\n' 'Usage: retroarch-game.sh CORE_FILE ROM_PATH' >&2
  exit 64
fi

core_file="$1"
rom_path="$2"
core_root="/usr/lib64/libretro"
if [[ ! "${core_file}" =~ ^[A-Za-z0-9._-]+_libretro\.so$ ]]; then
  printf '%s\n' 'Invalid RetroArch core name.' >&2
  exit 65
fi
core_path="$(realpath -e -- "${core_root}/${core_file}")"
rom_path="$(realpath -e -- "${rom_path}")"
case "${core_path}" in "${core_root}"/*) ;; *) printf '%s\n' 'Core path is outside the approved directory.' >&2; exit 65;; esac
case "${rom_path}" in /srv/library/games/roms/*) ;; *) printf '%s\n' 'Game path is outside Hearth personal library.' >&2; exit 66;; esac
test -r "${core_path}"
test -r "${rom_path}"
exec /usr/bin/retroarch --fullscreen -L "${core_path}" "${rom_path}"
