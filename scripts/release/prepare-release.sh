#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/release/release-common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/release-common.sh"

require_command hdiutil
require_command shasum
require_sparkle_tools

cd "$PROJECT_DIR"
if [[ "${QUILNODE_RELEASE_ALLOW_DIRTY:-0}" != "1" ]]; then
    if [[ -n "$(git status --porcelain)" ]]; then
        echo "Public release preparation requires a clean, committed source tree." >&2
        echo "QUILNODE_RELEASE_ALLOW_DIRTY=1 is reserved for local pipeline tests." >&2
        exit 1
    fi
    exact_tag="$(git describe --tags --exact-match 2>/dev/null || true)"
    if [[ -z "$exact_tag" ]]; then
        echo "Public release preparation requires HEAD to have an exact version tag." >&2
        exit 1
    fi
fi

app_path="$(scripts/build-app.sh | tail -1)"
if [[ ! -d "$app_path" ]]; then
    echo "Release build did not produce an application bundle." >&2
    exit 1
fi

version="$(bundle_value "$app_path" CFBundleShortVersionString)"
build="$(bundle_value "$app_path" CFBundleVersion)"
bundle_id="$(bundle_value "$app_path" CFBundleIdentifier)"
if [[ "$bundle_id" != "com.quilnode.app" ]]; then
    echo "Unexpected bundle identifier: $bundle_id" >&2
    exit 1
fi

release_root="${QUILNODE_RELEASE_OUTPUT_DIR:-$WORKSPACE_DIR/artifacts/releases/QuilNode-$version-$build}"
archives="$release_root/archives"
feed="$release_root/feed"
verification="$release_root/verification"
if [[ -e "$release_root" ]]; then
    echo "Refusing to overwrite an existing release directory: $release_root" >&2
    exit 1
fi
mkdir -p "$archives" "$feed" "$verification"

source_folder="$(mktemp -d -t quilnode-dmg-source)"
trap 'rm -rf "$source_folder"' EXIT
ditto --norsrc --noextattr --noqtn "$app_path" "$source_folder/QuilNode.app"
ln -s /Applications "$source_folder/Applications"
xattr -cr "$source_folder"
"$PROJECT_DIR/scripts/release/audit-metadata-privacy.sh" artifact "$source_folder"
dmg="$archives/QuilNode-$version.dmg"
hdiutil create -quiet -fs HFS+ -format UDZO -volname "QuilNode $version" -srcfolder "$source_folder" "$dmg"

generate_feed() {
    local key="$1"
    "$SPARKLE_TOOLS_DIR/generate_appcast" \
        --ed-key-file "$key" \
        --download-url-prefix "https://github.com/$REPOSITORY_SLUG/releases/download/v$version/" \
        --link "https://quilnode.com" \
        --maximum-deltas 0 \
        --maximum-versions 5 \
        -o "$feed/appcast.xml" \
        "$archives"
    "$SPARKLE_TOOLS_DIR/sign_update" --ed-key-file "$key" "$feed/appcast.xml" >/dev/null
    "$SPARKLE_TOOLS_DIR/sign_update" --verify --ed-key-file "$key" "$feed/appcast.xml"
    archive_signature="$(xmllint --xpath \
        'string(//*[local-name()="enclosure"]/@*[local-name()="edSignature"])' \
        "$feed/appcast.xml")"
    if [[ -z "$archive_signature" ]]; then
        echo "Generated appcast is missing the archive signature." >&2
        exit 1
    fi
    "$SPARKLE_TOOLS_DIR/sign_update" --verify --ed-key-file "$key" "$dmg" "$archive_signature"
}
with_decrypted_update_key generate_feed

codesign --verify --deep --strict --verbose=2 "$app_path"
spctl --assess --type execute --verbose=4 "$app_path" > "$verification/gatekeeper-assessment.txt" 2>&1 || true
codesign -dvvv "$app_path" > "$verification/code-signing.txt" 2>&1
spctl -a -vvv -t install "$dmg" > "$verification/dmg-assessment.txt" 2>&1 || true
(cd "$release_root" && shasum -a 256 "archives/$(basename "$dmg")" "feed/appcast.xml") > "$release_root/SHA256SUMS"
swift package show-dependencies --format json > "$verification/swift-dependencies.json"

source_commit="$(git rev-parse --verify HEAD 2>/dev/null || true)"
if [[ -z "$source_commit" ]]; then
    source_commit="uncommitted-development-snapshot"
fi

cat > "$release_root/RELEASE.txt" <<EOF
QuilNode $version ($build)
Bundle identifier: $bundle_id
Source commit: $source_commit
Sparkle: 2.9.6 exact pin
Update archive: $(basename "$dmg")
Feed: feed/appcast.xml
Automatic installation: disabled
System profiling: disabled
Distribution profile: community-signed
Apple notarization: not included
EOF

echo "$release_root"
