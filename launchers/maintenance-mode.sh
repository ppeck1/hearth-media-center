#!/usr/bin/env bash
set -euo pipefail

state_dir="${XDG_STATE_HOME:-${HOME}/.local/state}/living-room-appliance"
mkdir -p "${state_dir}"
printf '%s maintenance-test-started\n' "$(date --iso-8601=seconds)" >> "${state_dir}/launcher.log"

/usr/bin/zenity \
  --info \
  --width=520 \
  --title="Hearth maintenance test" \
  --text="Launch and return succeeded.\n\nThe full maintenance desktop will be enabled only after the dedicated media account exists."

