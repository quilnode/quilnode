#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app="${1:-}"
output="${2:-}"
[[ -d "$app" && -n "$output" && ! -e "$output" ]] || {
    echo "Usage: $0 /path/to/QuilNode.app /new/output.dmg" >&2; exit 64;
}
version="$(python3 -B "$script_dir/release-version.py" "$app/Contents/Info.plist" releaseVersion)"
volume="QuilNode $version"
mount_point="/Volumes/$volume"
[[ ! -e "$mount_point" ]] || { echo "Eject the existing $volume installer first." >&2; exit 1; }

# One coordinate system for the background and Finder's real draggable icons.
width=660
height=420
app_x=175
applications_x=485
icon_y=210

temporary="$(mktemp -d -t quilnode-dmg)"
attached=false
cleanup() {
    if [[ "$attached" == true ]]; then
        hdiutil detach -quiet "$mount_point" || return
    fi
    rm -rf "$temporary"
}
trap cleanup EXIT
mkdir -p "$temporary/source/.background"
ditto --norsrc --noextattr --noqtn "$app" "$temporary/source/QuilNode.app"
ln -s /Applications "$temporary/source/Applications"
touch "$temporary/source/.metadata_never_index"
xcrun swift "$script_dir/dmg-background.swift" "$temporary/source/.background/background.png" \
    "$width" "$height" "$app_x" "$applications_x" "$icon_y"
hdiutil create -quiet -fs HFS+ -format UDRW -volname "$volume" \
    -srcfolder "$temporary/source" "$temporary/writable.dmg"
hdiutil attach -quiet -readwrite -nobrowse -noautoopen -owners off \
    -mountpoint "$mount_point" "$temporary/writable.dmg"
attached=true
osascript "$script_dir/dmg-layout.applescript" "$volume" \
    "$width" "$height" "$app_x" "$applications_x" "$icon_y"
[[ -f "$mount_point/.DS_Store" ]] || { echo "Finder did not save the installer layout." >&2; exit 1; }
# Never follow the Applications link while cleaning build metadata.
xattr -crs "$mount_point"
"$script_dir/audit-metadata-privacy.sh" artifact "$mount_point"
hdiutil detach -quiet "$mount_point"
attached=false
hdiutil convert -quiet "$temporary/writable.dmg" -format UDZO -o "$output"
hdiutil verify -quiet "$output"
echo "$output"
