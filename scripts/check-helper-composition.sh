#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

shared_sources=()
while IFS= read -r source; do shared_sources+=("$source"); done < <(
    find Sources/QuilNodeShared -type f -name '*.swift' -print | sort
)
helper_sources=()
while IFS= read -r source; do helper_sources+=("$source"); done < <(
    find Sources/QuilNodeHelperKit Sources/QuilNodeHelperCLI -type f -name '*.swift' -print | sort
)

xcrun swiftc \
    -typecheck \
    -parse-as-library \
    -target arm64-apple-macos14.0 \
    "${shared_sources[@]}" \
    "${helper_sources[@]}"

echo "PASS: Shared and HelperKit compose into the sealed release-helper module"
