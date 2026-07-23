#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 2 ]]; then
  printf '%s\n' 'Usage: retroarch-game.sh CORE_FILE ROM_PATH' >&2
  exit 64
fi

core_file="$1"
rom_path="$2"
if [[ ! "${core_file}" =~ ^[A-Za-z0-9._-]+_libretro\.so$ ]]; then
  printf '%s\n' 'Invalid RetroArch core name.' >&2
  exit 65
fi
config_root="${XDG_CONFIG_HOME:-${HOME}/.config}"
approved_core_roots=("${config_root}/retroarch/cores" "/usr/lib64/libretro")
core_path=""
for core_root in "${approved_core_roots[@]}"; do
  candidate="${core_root}/${core_file}"
  if [[ -e "${candidate}" ]]; then
    core_path="$(realpath -e -- "${candidate}")"
    case "${core_path}" in
      "${core_root}"/*) ;;
      *) printf '%s\n' 'Core path is outside the approved directories.' >&2; exit 65 ;;
    esac
    break
  fi
done
if [[ -z "${core_path}" ]]; then
  printf 'RetroArch core is not installed: %s\n' "${core_file}" >&2
  exit 67
fi
rom_path="$(realpath -e -- "${rom_path}")"
case "${rom_path}" in /srv/library/games/roms/*) ;; *) printf '%s\n' 'Game path is outside Hearth personal library.' >&2; exit 66;; esac
test -r "${core_path}"
test -r "${rom_path}"
exec /usr/bin/retroarch --fullscreen -L "${core_path}" "${rom_path}"
