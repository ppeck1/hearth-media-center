#!/usr/bin/env bash
set -euo pipefail

service_id="${1:?service id required}"
service_url="${2:?service url required}"
destination_id="${3:-${service_id}}"
profile_root="${XDG_CONFIG_HOME:-${HOME}/.config}/media-kiosk/${service_id}"
mkdir -p "${profile_root}"

exec /opt/hearth/launchers/run-with-input-bridge.sh "${destination_id}" \
  /usr/bin/google-chrome-stable \
  --user-data-dir="${profile_root}" \
  --no-first-run \
  --disable-session-crashed-bubble \
  --start-fullscreen \
  --app="${service_url}"

