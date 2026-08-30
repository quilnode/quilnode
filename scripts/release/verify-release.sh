#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/release/release-common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/release-common.sh"

release_root="${1:-}"
if [[ -z "$release_root" || ! -d "$release_root" ]]; then
    echo "Usage: $0 /path/to/QuilNode-version-build" >&2
    exit 64
fi

dmg="$(find "$release_root/archives" -maxdepth 1 -type f -name 'QuilNode-*.dmg' -print -quit)"
appcast="$release_root/feed/appcast.xml"
[[ -r "$dmg" && -r "$appcast" && -r "$release_root/SHA256SUMS" ]] || {
    echo "Release artifact set is incomplete." >&2
    exit 1
}

(cd "$release_root" && shasum -a 256 -c SHA256SUMS)
plutil -lint "$appcast" >/dev/null 2>&1 || xmllint --noout "$appcast"
rg -q 'sparkle:edSignature=' "$appcast"
rg -q 'sparkle-signatures:' "$appcast"
rg -q "github\.com/quilnode/quilnode/releases/download/v[^/]+/QuilNode-[^\"]+\.dmg" "$appcast"

mount_point="$(mktemp -d -t quilnode-release-mount)"
attached=false
cleanup() {
    if [[ "$attached" == true ]]; then hdiutil detach -quiet "$mount_point" || true; fi
    rmdir "$mount_point" 2>/dev/null || true
}
trap cleanup EXIT
hdiutil attach -quiet -readonly -nobrowse -mountpoint "$mount_point" "$dmg"
attached=true
app="$mount_point/QuilNode.app"
codesign --verify --deep --strict --verbose=2 "$app"
"$PROJECT_DIR/scripts/release/audit-app-bundle.sh" "$app"
"$PROJECT_DIR/scripts/release/audit-metadata-privacy.sh" artifact "$app"
[[ "$(bundle_value "$app" CFBundleIdentifier)" == "com.quilnode.app" ]]
[[ "$(bundle_value "$app" SUPublicEDKey)" == "$UPDATE_PUBLIC_KEY" ]]
[[ "$(bundle_value "$app" SURequireSignedFeed)" == "true" ]]
[[ "$(bundle_value "$app" SUSignedFeedFailureExpirationInterval)" == "0" ]]
[[ "$(bundle_value "$app" SUVerifyUpdateBeforeExtraction)" == "true" ]]
[[ "$(bundle_value "$app" SUAllowsAutomaticUpdates)" == "false" ]]
[[ "$(bundle_value "$app" SUEnableSystemProfiling)" == "false" ]]
[[ -r "$app/Contents/Resources/QuilNodeReleaseSigning.cer" ]]
[[ ! -e "$app/Contents/Resources/qclient" ]]
[[ -d "$app/Contents/Frameworks/Sparkle.framework" ]]

echo "PASS: release hashes, signed feed metadata, app identity, Sparkle policy, and bundle boundary"
