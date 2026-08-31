#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"$script_dir/verify-release.sh" "$@"
python3 -B "$script_dir/tests/check_artifact_tampering.py" "$@"
