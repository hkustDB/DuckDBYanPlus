#!/usr/bin/env bash

set -euo pipefail
SCRIPT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec python3 "${SCRIPT_PATH}/scripts/run_required_retests.py" "$@"
