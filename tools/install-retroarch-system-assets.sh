#!/usr/bin/env bash
set -euo pipefail

config_root="${XDG_CONFIG_HOME:-${HOME}/.config}"
system_root="${config_root}/retroarch/system"
asset_root="https://buildbot.libretro.com/assets/system"
staging_root="$(mktemp -d)"
trap 'rm -rf -- "${staging_root}"' EXIT

for dependency in curl unzip; do
  if ! command -v "${dependency}" >/dev/null 2>&1; then
    printf 'Missing required command: %s\n' "${dependency}" >&2
    exit 2
  fi
done

mkdir -p "${system_root}"
for archive_name in Dolphin.zip blueMSX.zip LRPS2.zip PPSSPP.zip; do
  archive_path="${staging_root}/${archive_name}"
  printf 'Downloading generic support assets: %s\n' "${archive_name}"
  curl --fail --location --retry 3 --connect-timeout 10 \
    "${asset_root}/${archive_name}" --output "${archive_path}"
  if ! unzip -Z1 "${archive_path}" |
      awk '
        /^\// || /(^|\/)\.\.(\/|$)/ || /\\/ { unsafe = 1 }
        END { exit unsafe ? 1 : 0 }
      '; then
    printf 'Unsafe path found in support archive: %s\n' "${archive_name}" >&2
    exit 3
  fi
  unzip -oq "${archive_path}" -d "${system_root}"
  printf 'Installed support assets: %s\n' "${archive_name}"
done

test -s "${system_root}/dolphin-emu/Sys/GC/dsp_rom.bin"
test -s "${system_root}/Machines/COL - ColecoVision/config.ini"
test -s "${system_root}/pcsx2/resources/GameIndex.yaml"
test -s "${system_root}/PPSSPP/ppge_atlas.zim"
printf 'RetroArch support assets are ready under %s.\n' "${system_root}"
