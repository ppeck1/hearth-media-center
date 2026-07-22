#!/usr/bin/env bash
set -euo pipefail
exec /opt/hearth/launchers/run-with-input-bridge.sh plex \
  /usr/bin/flatpak run tv.plex.PlexHTPC

