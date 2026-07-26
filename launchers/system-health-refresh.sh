#!/usr/bin/env bash
set -euo pipefail

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
hearth_root="$(cd "$(dirname "${script_path}")/.." && pwd)"
state_root="${XDG_STATE_HOME:-${HOME}/.local/state}/hearth"
report_path="${state_root}/system-health.json"

install -d -m 0700 "${state_root}"
exec "${hearth_root}/deploy/fedora/doctor.sh" --json --output "${report_path}" >/dev/null
