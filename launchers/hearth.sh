#!/usr/bin/env bash
set -euo pipefail

script_path="$(readlink -f "${BASH_SOURCE[0]}")"
hearth_root="$(cd "$(dirname "${script_path}")/.." && pwd)"

exec "${hearth_root}/runtime/godot" \
  --path "${hearth_root}/launcher" \
  --display-driver wayland \
  --resolution 1920x1080
