#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
  printf 'Usage: pc-game.sh GAME_ID\n' >&2
  exit 64
fi

run_scummvm() {
  local game_path="$1"
  local target="$2"
  exec flatpak run org.scummvm.ScummVM \
    --fullscreen \
    --path="$game_path" \
    "$target"
}

run_dos() {
  local executable="$1"
  exec flatpak run io.github.dosbox-staging --fullscreen "$executable"
}

case "$1" in
  fate-of-atlantis)
    run_scummvm \
      /srv/library/games/pc/scummvm/fate-of-atlantis/ATLANTIS \
      scumm:atlantis
    ;;
  loom)
    run_scummvm \
      /srv/library/games/pc/scummvm/loom \
      scumm:loom
    ;;
  secret-of-monkey-island)
    run_scummvm \
      /srv/library/games/pc/scummvm/secret-of-monkey-island \
      scumm:monkey
    ;;
  monkey-island-2)
    run_scummvm \
      /srv/library/games/pc/scummvm/monkey-island-2/mi2 \
      scumm:monkey2
    ;;
  full-throttle)
    run_scummvm \
      /srv/library/games/pc/scummvm/full-throttle/data/RESOURCE \
      scumm:ft
    ;;
  return-to-zork)
    run_scummvm \
      /srv/library/games/pc/scummvm/return-to-zork \
      made:rtz
    ;;
  oregon-trail-1990)
    run_dos /srv/library/games/pc/dos/oregon-trail-1990/OREGON.EXE
    ;;
  lemmings)
    run_dos /srv/library/games/pc/dos/lemmings/runme.bat
    ;;
  mario-teaches-typing)
    run_dos /srv/library/games/pc/dos/mario-teaches-typing/MARIO.EXE
    ;;
  doom)
    exec flatpak run org.zdoom.UZDoom \
      -iwad /srv/library/games/pc/source-ports/doom/DOOM.WAD
    ;;
  doom-ii)
    exec flatpak run org.zdoom.UZDoom \
      -iwad /srv/library/games/pc/source-ports/doom/DOOM2.WAD
    ;;
  quake-shareware)
    exec flatpak run net.sourceforge.quakespasm.Quakespasm \
      -basedir /srv/library/games/pc/source-ports/quake-shareware
    ;;
  fallout)
    cd /srv/library/games/pc/source-ports/fallout-ce
    exec ./fallout-ce
    ;;
  muppet-treasure-island)
    exec flatpak run com.dosbox_x.DOSBox-X \
      -fastlaunch \
      -fullscreen \
      -c "mount c /srv/library/games/pc/windows/muppet-treasure-island" \
      -c "c:" \
      -c "imgmount e C:\MTI1.iso C:\MTI2.iso C:\MTI3.iso -t iso" \
      -c "windows\smartdrv.exe" \
      -c "set PATH=%PATH%;C:\WINDOWS" \
      -c "set TEMP=C:\WINDOWS\TEMP" \
      -c "set SOUND=C:\SB16" \
      -c "set BLASTER=A220 I7 D1 H5 P330 T6" \
      -c "windows\win /b C:\ACTIVISN\MTI\TREASURE.EXE"
    ;;
  *)
    printf 'Unsupported Hearth PC game: %s\n' "$1" >&2
    exit 64
    ;;
esac
