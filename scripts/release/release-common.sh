#!/usr/bin/env bash
set -euo pipefail

RELEASE_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$RELEASE_SCRIPT_DIR/../.." && pwd)"
WORKSPACE_DIR="${QUILNODE_WORKSPACE_DIR:-$(cd "$PROJECT_DIR/.." && pwd)/workspace}"
SPARKLE_TOOLS_DIR="${QUILNODE_SPARKLE_TOOLS_DIR:-$PROJECT_DIR/.build/xcode/SourcePackages/artifacts/sparkle/Sparkle/bin}"
ENCRYPTED_UPDATE_KEY="${QUILNODE_ENCRYPTED_UPDATE_KEY:-$WORKSPACE_DIR/private/release-identity/app-updates/offline/QuilNode-Sparkle-Ed25519.private.enc}"
UPDATE_KEY_PASSWORD_FILE="${QUILNODE_UPDATE_KEY_PASSWORD_FILE:-}"
# shellcheck disable=SC2034 # Exported to scripts that source this shared policy.
UPDATE_PUBLIC_KEY="DJIxXBjq/gVQx7fUypBouvqtsS1Qx7SKvBUAi/yKZp8="
# shellcheck disable=SC2034 # Exported to scripts that source this shared policy.
REPOSITORY_SLUG="quilnode/quilnode"

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Missing required command: $1" >&2
        exit 1
    }
}

require_sparkle_tools() {
    for tool in generate_appcast sign_update; do
        if [[ ! -x "$SPARKLE_TOOLS_DIR/$tool" ]]; then
            echo "Missing Sparkle 2.9.6 tool: $SPARKLE_TOOLS_DIR/$tool" >&2
            echo "Run xcodebuild package resolution before preparing a release." >&2
            exit 1
        fi
    done
}

with_decrypted_update_key() {
    local callback="$1"
    shift
    if [[ -z "$UPDATE_KEY_PASSWORD_FILE" || ! -r "$UPDATE_KEY_PASSWORD_FILE" ]]; then
        echo "Set QUILNODE_UPDATE_KEY_PASSWORD_FILE to the separately held release-key password file." >&2
        exit 1
    fi
    if [[ ! -r "$ENCRYPTED_UPDATE_KEY" ]]; then
        echo "Encrypted application-update key is unavailable: $ENCRYPTED_UPDATE_KEY" >&2
        exit 1
    fi
    # The subshell owns an EXIT trap even when signing fails; it cannot replace
    # the packager's separate disk-image cleanup trap.
    (
        umask 077
        key_directory="$(mktemp -d -t quilnode-release-key)"
        trap 'rm -rf "$key_directory"' EXIT
        trap 'exit 130' INT
        trap 'exit 143' TERM HUP
        temporary_key="$key_directory/update.key"
        openssl enc -d -aes-256-cbc -pbkdf2 -iter 600000 \
            -in "$ENCRYPTED_UPDATE_KEY" -out "$temporary_key" \
            -pass "file:$UPDATE_KEY_PASSWORD_FILE" || exit 1
        "$callback" "$temporary_key" "$@"
    )
}

bundle_value() {
    /usr/libexec/PlistBuddy -c "Print :$2" "$1/Contents/Info.plist"
}
