#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=scripts/release/release-common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/release-common.sh"
require_sparkle_tools

fixture="$(mktemp -t quilnode-update-signature-fixture)"
trap 'rm -f "$fixture"' EXIT
printf '%s\n' 'QuilNode application update signing fixture v1' > "$fixture"

test_signature() {
    local key="$1"
    local signature
    signature="$("$SPARKLE_TOOLS_DIR/sign_update" --ed-key-file "$key" -p "$fixture")"
    "$SPARKLE_TOOLS_DIR/sign_update" --verify --ed-key-file "$key" "$fixture" "$signature"
    printf '%s\n' 'tamper' >> "$fixture"
    if "$SPARKLE_TOOLS_DIR/sign_update" --verify --ed-key-file "$key" "$fixture" "$signature" >/dev/null 2>&1; then
        echo "Tampered update fixture was accepted." >&2
        exit 1
    fi
}
with_decrypted_update_key test_signature
echo "PASS: offline Ed25519 update key signs valid content and rejects tampering"
