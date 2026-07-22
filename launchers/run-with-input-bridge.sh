#!/usr/bin/env bash
set -euo pipefail

destination_id="${1:?destination id required}"
shift
if (( $# == 0 )); then
  echo "run-with-input-bridge: application command required" >&2
  exit 2
fi

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
hearth_root="$(cd "$(dirname "${script_path}")/.." && pwd)"
bridge_root="${hearth_root}/input_bridge"
config_root="${hearth_root}/launcher/config"

if [[ ! -d "${bridge_root}/hearth_input_bridge" ]]; then
  echo "run-with-input-bridge: ${bridge_root} is not deployed" >&2
  exit 2
fi

bridge_pythonpath="${bridge_root}${PYTHONPATH:+:${PYTHONPATH}}"
exec env PYTHONPATH="${bridge_pythonpath}" python3 -m hearth_input_bridge run \
  --config-dir "${config_root}" \
  --profile ps5 \
  --destination "${destination_id}" \
  -- "$@"
