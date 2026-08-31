#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=scripts/release/release-common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/release-common.sh"
release_root="${1:-}"
mode_args=()
if [[ "${2:-}" == "--rehearsal" ]]; then mode_args=(--rehearsal)
elif [[ -n "${2:-}" ]]; then exit 64; fi
[[ -d "$release_root" && $# -le 2 ]] || {
    echo "Usage: $0 /path/to/release-directory [--rehearsal]" >&2; exit 64;
}
temporary="$(mktemp -d -t quilnode-release-verification)"
mount_point="$temporary/mount"
mkdir "$mount_point"
attached=false
cleanup() {
    if [[ "$attached" == true ]]; then hdiutil detach -quiet "$mount_point" || return; fi
    rm -rf "$temporary"
}
trap cleanup EXIT
xcrun swiftc -O "$RELEASE_SCRIPT_DIR/verify-ed25519.swift" -o "$temporary/verify-ed25519"
# Authenticate every archive byte before mounting it. No private key is read.
name="$(python3 -B "$RELEASE_SCRIPT_DIR/release-evidence.py" verify \
    "$release_root" "$temporary/verify-ed25519" "$UPDATE_PUBLIC_KEY" ${mode_args[@]+"${mode_args[@]}"})"
hdiutil verify -quiet "$release_root/$name"
hdiutil attach -quiet -readonly -nobrowse -noautoopen -owners off -mountpoint "$mount_point" "$release_root/$name"
attached=true
app="$mount_point/QuilNode.app"
[[ -L "$mount_point/Applications" && "$(readlink "$mount_point/Applications")" == "/Applications" ]]
[[ -f "$mount_point/.DS_Store" && -f "$mount_point/.background/background.png" ]]
"$RELEASE_SCRIPT_DIR/audit-app-bundle.sh" "$app"
"$RELEASE_SCRIPT_DIR/audit-metadata-privacy.sh" artifact "$mount_point"
python3 -B "$RELEASE_SCRIPT_DIR/release-evidence.py" verify-bundle "$app" "$release_root"
[[ "$(bundle_value "$app" SUSignedFeedFailureExpirationInterval)" == "0" ]]
[[ "$(bundle_value "$app" SUAutomaticallyUpdate)" == "false" ]]
echo "PASS: report, feed and archive signatures; exact version, hashes, licenses, SBOM inventory and delivered bundle"
