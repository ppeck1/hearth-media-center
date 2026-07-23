#!/usr/bin/env bash
set -euo pipefail

service_id="${1:?service id required}"
service_url="${2:?service url required}"
destination_id="${3:-${service_id}}"
profile_root="${XDG_CONFIG_HOME:-${HOME}/.config}/media-kiosk/${service_id}"
extension_root="/opt/hearth/browser_extension"
mkdir -p "${profile_root}"
test -f "${extension_root}/manifest.json"

exec /opt/hearth/launchers/run-with-input-bridge.sh "${destination_id}" \
  /usr/bin/google-chrome-stable \
  --user-data-dir="${profile_root}" \
  --no-first-run \
  --disable-session-crashed-bubble \
  --disable-extensions-except="${extension_root}" \
  --load-extension="${extension_root}" \
  --enable-spatial-navigation \
  --start-fullscreen \
  --app="${service_url}"
