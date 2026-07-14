#!/usr/bin/env sh
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
exec python3 "$project_root/Tools/run_web.py" "$@"
