#!/usr/bin/env bash
set -euo pipefail
if /usr/bin/zenity --question --title="Shut down Hearth?" --text="Shut down the living-room PC now?" --ok-label="Shut Down" --cancel-label="Cancel"; then
  exec /usr/bin/systemctl poweroff
fi
