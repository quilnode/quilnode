#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/release/release-common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/release-common.sh"

release_root="${1:-}"
[[ -d "$release_root" ]] || { echo "Usage: $0 /path/to/release-directory" >&2; exit 64; }

report_dir="$release_root/verification/clean-macos"
mkdir -p "$report_dir"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
report="$report_dir/$timestamp.txt"

{
    echo "QuilNode clean-mac static qualification"
    echo "Date UTC: $timestamp"
    echo "macOS: $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
    echo "Architecture: $(uname -m)"
    echo "Host: redacted"
    echo
    "$RELEASE_SCRIPT_DIR/verify-release.sh" "$release_root"
    echo
    echo "Gatekeeper assessment (a rejection is expected without Developer ID notarization):"
    dmg="$(find "$release_root/archives" -maxdepth 1 -type f -name 'QuilNode-*.dmg' -print -quit)"
    spctl -a -vvv -t install "$dmg" 2>&1 || true
    echo
    echo "Manual fresh-machine first-open and N→N+1 rows remain mandatory."
} | tee "$report"

echo "$report"
