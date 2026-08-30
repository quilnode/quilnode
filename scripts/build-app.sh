#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORKSPACE_DIR="${QUILNODE_WORKSPACE_DIR:-$(cd "$PROJECT_DIR/.." && pwd)/workspace}"
# shellcheck source=scripts/release/toolchain-policy.sh
source "$PROJECT_DIR/scripts/release/toolchain-policy.sh"
DIST_DIR="${QUILNODE_DIST_DIR:-$WORKSPACE_DIR/artifacts/app-builds}"
APP_DIR="$DIST_DIR/QuilNode.app"
SIGNING_NAME="${QUILNODE_SIGNING_NAME:-QuilNode Project Release Signing}"
SIGNING_DIR="${QUILNODE_SIGNING_DIR:-$WORKSPACE_DIR/private/release-identity/app-signing}"
SIGNING_KEYCHAIN="${QUILNODE_SIGNING_KEYCHAIN:-$SIGNING_DIR/quilnode-release-signing.keychain-db}"
SIGNING_PASSWORD_FILE="${QUILNODE_SIGNING_PASSWORD_FILE:-$SIGNING_DIR/keychain-password}"
SIGN_ARGS=()
SIGNING_CERTIFICATE="${QUILNODE_SIGNING_CERTIFICATE:-$PROJECT_DIR/Resources/QuilNodeReleaseSigning.cer}"
RELEASE_VERIFIER_SOURCE="$PROJECT_DIR/Sources/QuilNodeReleaseVerifier/main.c"
OPENSSL_PREFIX="${QUILNODE_OPENSSL_PREFIX:-}"
BUNDLE_IDENTIFIER="${QUILNODE_BUNDLE_IDENTIFIER:-com.quilnode.app}"

# The legacy value exists only for the one-time, same-certificate bridge from
# pre-1.0 local installations. Arbitrary identifiers are never signed by this
# release script because the privileged service authorizes only these two exact
# application identities.
case "$BUNDLE_IDENTIFIER" in
    com.quilnode.app|local.quilnode.operator) ;;
    *)
        echo "Unsupported QuilNode bundle identifier: $BUNDLE_IDENTIFIER" >&2
        exit 1
        ;;
esac

if [[ ! -r "$SIGNING_CERTIFICATE" ]]; then
    echo "Missing public signing certificate: $SIGNING_CERTIFICATE" >&2
    echo "Set QUILNODE_SIGNING_CERTIFICATE to the certificate embedded for local-service pinning." >&2
    exit 1
fi

if [[ -z "$OPENSSL_PREFIX" ]]; then
    OPENSSL_PREFIX="$(quilnode_default_openssl_toolchain "$WORKSPACE_DIR")"
fi
if [[ ! -r "$OPENSSL_PREFIX/include/openssl/evp.h" || ! -r "$OPENSSL_PREFIX/lib/libcrypto.a" ]]; then
    echo "Missing the pinned OpenSSL 3.5.8 LTS macOS 14 release toolchain." >&2
    echo "Run scripts/release/build-openssl-toolchain.sh first, or set QUILNODE_OPENSSL_PREFIX to an equivalent audited prefix." >&2
    echo "This is a release-builder dependency only; node operators do not install it." >&2
    exit 1
fi

build_release_verifier() {
    local output="$1"
    local build_log
    build_log="$(mktemp -t quilnode-verifier-build).log"
    if ! xcrun clang \
        -O2 -g0 -Wall -Wextra -Werror \
        -ffile-prefix-map="$PROJECT_DIR=/usr/src/quilnode" \
        -fdebug-prefix-map="$PROJECT_DIR=/usr/src/quilnode" \
        -fmacro-prefix-map="$PROJECT_DIR=/usr/src/quilnode" \
        -target arm64-apple-macos14.0 \
        -I"$OPENSSL_PREFIX/include" \
        "$RELEASE_VERIFIER_SOURCE" \
        "$OPENSSL_PREFIX/lib/libcrypto.a" \
        -framework Security -framework CoreFoundation \
        -o "$output" 2>"$build_log"; then
        sed -n '1,200p' "$build_log" >&2
        rm -f "$build_log"
        exit 1
    fi
    if rg -q "built for newer 'macOS' version" "$build_log"; then
        sed -n '1,40p' "$build_log" >&2
        echo "The verifier dependency was built for a newer macOS deployment target." >&2
        rm -f "$build_log"
        exit 1
    fi
    rm -f "$build_log"
    chmod 755 "$output"
}

if [[ -r "$SIGNING_PASSWORD_FILE" && -f "$SIGNING_KEYCHAIN" ]]; then
    keychain_is_listed=false
    existing_keychains=()
    while IFS= read -r listed_keychain; do
        listed_keychain="${listed_keychain#*\"}"
        listed_keychain="${listed_keychain%\"*}"
        [[ -n "$listed_keychain" ]] || continue
        existing_keychains+=("$listed_keychain")
        [[ "$listed_keychain" == "$SIGNING_KEYCHAIN" ]] && keychain_is_listed=true
    done < <(security list-keychains -d user)
    if [[ "$keychain_is_listed" == false ]]; then
        security list-keychains -d user -s "$SIGNING_KEYCHAIN" "${existing_keychains[@]}"
    fi
    security unlock-keychain -p "$(<"$SIGNING_PASSWORD_FILE")" "$SIGNING_KEYCHAIN"
    # The helper pins the leaf certificate itself, so this local identity does
    # not need broad system trust. Presence of its certificate and private key
    # in the dedicated locked keychain is enough for deterministic signing.
    if security find-certificate -c "$SIGNING_NAME" "$SIGNING_KEYCHAIN" >/dev/null 2>&1; then
        SIGN_ARGS=(--force --sign "$SIGNING_NAME" --keychain "$SIGNING_KEYCHAIN" --options runtime --timestamp=none)
    fi
fi

if (( ${#SIGN_ARGS[@]} == 0 )); then
    echo "The project release signing identity is unavailable." >&2
    echo "Public and privileged-service builds must never fall back to an ad-hoc identity." >&2
    echo "Expected keychain: $SIGNING_KEYCHAIN" >&2
    exit 1
fi

expected_certificate_sha256="$(openssl x509 -inform der -in "$SIGNING_CERTIFICATE" -noout -fingerprint -sha256 | cut -d= -f2 | tr -d :)"
keychain_certificate="$(mktemp -t quilnode-signing-certificate).pem"
security find-certificate -c "$SIGNING_NAME" -p "$SIGNING_KEYCHAIN" > "$keychain_certificate"
keychain_certificate_sha256="$(openssl x509 -in "$keychain_certificate" -noout -fingerprint -sha256 | cut -d= -f2 | tr -d :)"
rm -f "$keychain_certificate"
if [[ "$expected_certificate_sha256" != "$keychain_certificate_sha256" ]]; then
    echo "The embedded public certificate does not match the private signing identity." >&2
    exit 1
fi

if [[ -f "$PROJECT_DIR/project.yml" && -x "$(command -v xcodegen)" ]]; then
    XCODE_DERIVED_DIR="$PROJECT_DIR/.build/xcode"

    # A release candidate must never inherit resources from an earlier local
    # project revision. Removing this exact generated product is safer than
    # relying on Xcode's incremental resource-copy behavior.
    rm -rf "$XCODE_DERIVED_DIR/Build/Products/Release/QuilNode.app"

    xcodegen generate --spec "$PROJECT_DIR/project.yml" --project "$PROJECT_DIR"
    xcodebuild \
        -project "$PROJECT_DIR/QuilNode.xcodeproj" \
        -scheme QuilNode \
        -configuration Release \
        -destination "platform=macOS,arch=arm64" \
        -derivedDataPath "$XCODE_DERIVED_DIR" \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_REQUIRED=NO \
        SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
        GCC_TREAT_WARNINGS_AS_ERRORS=YES \
        PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_IDENTIFIER" \
        build

    BUILT_APP="$XCODE_DERIVED_DIR/Build/Products/Release/QuilNode.app"
    BUILT_HELPER="$BUILT_APP/Contents/Helpers/QuilNodeHelper"
    BUILT_VERIFIER="$BUILT_APP/Contents/Helpers/QuilNodeReleaseVerifier"
    BUILT_RESOURCES="$BUILT_APP/Contents/Resources"
    # Xcode incremental builds do not remove resources deleted from a previous
    # project revision. qclient must never survive in the distributable app.
    rm -f "$BUILT_RESOURCES/qclient" "$BUILT_RESOURCES/QuilNodeLocalSigning.cer"
    mkdir -p "$(dirname "$BUILT_HELPER")"
    shared_sources=()
    while IFS= read -r source; do shared_sources+=("$source"); done < <(
        find "$PROJECT_DIR/Sources/QuilNodeShared" -type f -name '*.swift' -print | sort
    )
    helper_sources=()
    while IFS= read -r source; do helper_sources+=("$source"); done < <(
        find "$PROJECT_DIR/Sources/QuilNodeHelperKit" "$PROJECT_DIR/Sources/QuilNodeHelperCLI" \
            -type f -name '*.swift' -print | sort
    )
    xcrun swiftc \
        -O \
        -parse-as-library \
        -target arm64-apple-macos14.0 \
        "${shared_sources[@]}" \
        "${helper_sources[@]}" \
        -o "$BUILT_HELPER"
    chmod 755 "$BUILT_HELPER"
    build_release_verifier "$BUILT_VERIFIER"
    # XcodeGen does not create a Copy Bundle Resources phase when the only
    # application resource is a DER certificate. Install it explicitly before
    # signing so the privileged-service bootstrap can pin this exact identity.
    mkdir -p "$BUILT_RESOURCES"
    cp "$SIGNING_CERTIFICATE" \
        "$BUILT_RESOURCES/QuilNodeReleaseSigning.cer"
    chmod 644 "$BUILT_RESOURCES/QuilNodeReleaseSigning.cer"
    cp "$PROJECT_DIR/Resources/AppIcon.icns" "$BUILT_RESOURCES/AppIcon.icns"
    chmod 644 "$BUILT_RESOURCES/AppIcon.icns"
    # Git does not preserve xattrs, but local source and dependency caches can.
    # Strip them before signing so Finder metadata, quarantine, provenance, and
    # resource forks cannot become release inputs.
    xattr -cr "$BUILT_APP"
    # Sparkle's nested XPC services and updater app must satisfy the same host
    # identity requirement. Sign bundle boundaries inside-out, then seal the
    # framework and finally the host app. Avoid `--deep`, which can hide an
    # accidentally introduced nested executable during release packaging.
    SPARKLE_FRAMEWORK="$BUILT_APP/Contents/Frameworks/Sparkle.framework"
    if [[ ! -d "$SPARKLE_FRAMEWORK" ]]; then
        echo "Pinned Sparkle framework is missing from the application bundle." >&2
        exit 1
    fi
    while IFS= read -r -d '' nested_bundle; do
        codesign "${SIGN_ARGS[@]}" --preserve-metadata=entitlements,requirements "$nested_bundle"
    done < <(find "$SPARKLE_FRAMEWORK" -depth -type d \( -name '*.xpc' -o -name '*.app' \) -print0)
    codesign "${SIGN_ARGS[@]}" "$SPARKLE_FRAMEWORK/Versions/Current/Autoupdate"
    codesign "${SIGN_ARGS[@]}" "$SPARKLE_FRAMEWORK"
    codesign "${SIGN_ARGS[@]}" "$BUILT_VERIFIER"
    codesign "${SIGN_ARGS[@]}" "$BUILT_HELPER"
    codesign \
        "${SIGN_ARGS[@]}" \
        --entitlements "$PROJECT_DIR/Resources/QuilNode.entitlements" \
        "$BUILT_APP"
    if [[ -e "$BUILT_RESOURCES/qclient" ]]; then
        echo "Security invariant failed: qclient was embedded in QuilNode.app" >&2
        exit 1
    fi

    mkdir -p "$DIST_DIR"
    if [[ -e "$APP_DIR" ]]; then
        mv "$APP_DIR" "/tmp/QuilNode-dist-previous-$(date +%Y%m%d-%H%M%S).app"
    fi
    ditto --norsrc --noextattr --noqtn "$BUILT_APP" "$APP_DIR"
    "$PROJECT_DIR/scripts/release/audit-app-bundle.sh" "$APP_DIR" "$SIGNING_NAME"
    signed_authority="$(codesign -dvv "$APP_DIR" 2>&1 | sed -n 's/^Authority=//p' | head -1)"
    if [[ "$signed_authority" != "$SIGNING_NAME" ]]; then
        echo "Built application authority mismatch: $signed_authority" >&2
        exit 1
    fi
    echo "$APP_DIR"
    exit 0
fi

echo "A release build requires Xcode and XcodeGen so the exact-pinned Sparkle framework is embedded safely." >&2
exit 1
