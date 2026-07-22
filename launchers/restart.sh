#!/usr/bin/env bash
set -euo pipefail
if /usr/bin/zenity --question --title="Restart Hearth?" --text="Restart the living-room PC now?" --ok-label="Restart" --cancel-label="Cancel"; then
  exec /usr/bin/systemctl reboot
fi
