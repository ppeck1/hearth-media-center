#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
  printf 'Usage: devilutionx-game.sh diablo|hellfire\n' >&2
  exit 64
fi

case "$1" in
  diablo)
    exec flatpak run org.diasurgical.DevilutionX \
      --data-dir /srv/library/games/pc/source-ports/diablo
    ;;
  hellfire)
    exec flatpak run org.diasurgical.DevilutionX \
      --data-dir /srv/library/games/pc/source-ports/diablo \
      --hellfire
    ;;
  *)
    printf 'Unsupported DevilutionX game mode: %s\n' "$1" >&2
    exit 64
    ;;
esac
