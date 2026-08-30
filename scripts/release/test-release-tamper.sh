#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/release/release-common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/release-common.sh"
require_sparkle_tools

release_root="${1:-}"
[[ -d "$release_root" ]] || { echo "Usage: $0 /path/to/release-directory" >&2; exit 64; }
dmg="$(find "$release_root/archives" -maxdepth 1 -type f -name 'QuilNode-*.dmg' -print -quit)"
appcast="$release_root/feed/appcast.xml"

run_tamper_tests() {
    local key="$1"
    local signature tampered_dmg tampered_feed
    signature="$(xmllint --xpath \
        'string(//*[local-name()="enclosure"]/@*[local-name()="edSignature"])' \
        "$appcast")"
    "$SPARKLE_TOOLS_DIR/sign_update" --verify --ed-key-file "$key" "$dmg" "$signature"
    "$SPARKLE_TOOLS_DIR/sign_update" --verify --ed-key-file "$key" "$appcast"

    tampered_dmg="$(mktemp -t quilnode-tampered-update).dmg"
    tampered_feed="$(mktemp -t quilnode-tampered-appcast).xml"
    trap 'rm -f "$tampered_dmg" "$tampered_feed"' RETURN
    cp "$dmg" "$tampered_dmg"
    cp "$appcast" "$tampered_feed"
    printf 'tamper' >> "$tampered_dmg"
    perl -0pi -e 's#<title>QuilNode</title>#<title>Tampered</title>#' "$tampered_feed"

    if "$SPARKLE_TOOLS_DIR/sign_update" --verify --ed-key-file "$key" "$tampered_dmg" "$signature" >/dev/null 2>&1; then
        echo "Tampered application archive was accepted." >&2
        exit 1
    fi
    if "$SPARKLE_TOOLS_DIR/sign_update" --verify --ed-key-file "$key" "$tampered_feed" >/dev/null 2>&1; then
        echo "Tampered signed feed was accepted." >&2
        exit 1
    fi
    rm -f "$tampered_dmg" "$tampered_feed"
    trap - RETURN
}

with_decrypted_update_key run_tamper_tests
echo "PASS: exact release archive and feed verify; content tampering is rejected"
