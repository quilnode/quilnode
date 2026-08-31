#!/usr/bin/env bash
set -euo pipefail

# Build locally. Never create a tag, upload assets, or publish the appcast.
# shellcheck source=scripts/release/release-common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/release-common.sh"
mode=release
mode_args=()
case "${1:-}" in
    "") ;;
    --rehearsal) mode=rehearsal; mode_args=(--rehearsal) ;;
    *) echo "Usage: $0 [--rehearsal]" >&2; exit 64 ;;
esac
(( $# <= 1 )) || exit 64
[[ "${QUILNODE_RELEASE_ALLOW_DIRTY:-0}" == "0" ]] || {
    echo "Dirty-tree bypasses are no longer supported. Commit the candidate first." >&2; exit 1;
}
require_command hdiutil
require_command python3
require_sparkle_tools
[[ -n "$UPDATE_KEY_PASSWORD_FILE" && -r "$UPDATE_KEY_PASSWORD_FILE" && -r "$ENCRYPTED_UPDATE_KEY" ]] || {
    echo "Provide the separately held update-key password capability before packaging." >&2; exit 1;
}
cd "$PROJECT_DIR"
temporary="$(mktemp -d -t quilnode-release)"
trap 'rm -rf "$temporary"' EXIT

echo "1/6 — Pin the clean source candidate ($mode)" >&2
python3 -B "$RELEASE_SCRIPT_DIR/release-evidence.py" source "$temporary/source.json" ${mode_args[@]+"${mode_args[@]}"}
version="$(python3 -B "$RELEASE_SCRIPT_DIR/release-version.py" Resources/Info.plist releaseVersion)"
build="$(python3 -B "$RELEASE_SCRIPT_DIR/release-version.py" Resources/Info.plist build)"
tag="$(python3 -B "$RELEASE_SCRIPT_DIR/release-version.py" Resources/Info.plist tag)"
name="$(python3 -B "$RELEASE_SCRIPT_DIR/release-version.py" Resources/Info.plist dmg)"
timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
default_root="$WORKSPACE_DIR/artifacts/releases/QuilNode-$version-$build"
if [[ "$mode" == "rehearsal" ]]; then default_root="$default_root-rehearsal-$timestamp"; fi
release_root="${QUILNODE_RELEASE_OUTPUT_DIR:-$default_root}"
release_root="$(python3 -B "$RELEASE_SCRIPT_DIR/release-evidence.py" output-path "$release_root")"
mkdir -p "$release_root"
audit_dir="$WORKSPACE_DIR/audits/release-package-$timestamp"
mkdir -p "$audit_dir"
chmod 700 "$audit_dir"

echo "2/6 — Build and seal the app; log: $audit_dir/build.log" >&2
if ! scripts/build-app.sh > "$audit_dir/build.log" 2>&1; then
    tail -n 30 "$audit_dir/build.log" >&2
    echo "Build failed. The full private log is retained at $audit_dir/build.log" >&2
    exit 1
fi
app_path="$(tail -n 1 "$audit_dir/build.log")"
[[ -d "$app_path" ]] || { echo "Build did not return an application bundle." >&2; exit 1; }
echo "3/6 — Create the drag-to-Applications disk image" >&2
"$RELEASE_SCRIPT_DIR/build-dmg.sh" "$app_path" "$release_root/$name" >&2

sign_release() {
    local key="$1"
    echo "4/6 — Generate and sign the final update feed" >&2
    mkdir "$temporary/feed-input"
    cp "$release_root/$name" "$temporary/feed-input/$name"
    "$SPARKLE_TOOLS_DIR/generate_appcast" --ed-key-file "$key" \
        --download-url-prefix "https://github.com/$REPOSITORY_SLUG/releases/download/$tag/" \
        --link "https://quilnode.com" --maximum-deltas 0 --maximum-versions 1 \
        -o "$release_root/appcast.xml" "$temporary/feed-input" >&2
    python3 -B "$RELEASE_SCRIPT_DIR/release-version.py" "$app_path/Contents/Info.plist" label-feed \
        --feed "$release_root/appcast.xml" ${mode_args[@]+"${mode_args[@]}"}
    "$SPARKLE_TOOLS_DIR/sign_update" --ed-key-file "$key" "$release_root/appcast.xml" >/dev/null
    echo "5/6 — Seal the artifact inventory, SBOMs and release report" >&2
    python3 -B "$RELEASE_SCRIPT_DIR/release-evidence.py" report \
        "$app_path" "$release_root" "$temporary/source.json" ${mode_args[@]+"${mode_args[@]}"} >&2
    "$SPARKLE_TOOLS_DIR/sign_update" --ed-key-file "$key" -p "$release_root/release-report.json" \
        > "$release_root/release-report.sig"
    python3 -B "$RELEASE_SCRIPT_DIR/release-evidence.py" checksums "$release_root"
}
with_decrypted_update_key sign_release
echo "6/6 — Verify signatures, delivered bundle and installer contents using public keys" >&2
"$RELEASE_SCRIPT_DIR/verify-release.sh" "$release_root" ${mode_args[@]+"${mode_args[@]}"} >&2
if [[ "$mode" == "rehearsal" ]]; then
    echo "LOCAL REHEARSAL ONLY — source tag and clean-machine qualification are not attested." >&2
fi
echo "$release_root"
