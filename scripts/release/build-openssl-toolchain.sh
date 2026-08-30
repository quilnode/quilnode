#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKSPACE_DIR="${QUILNODE_WORKSPACE_DIR:-$(cd "$PROJECT_DIR/.." && pwd)/workspace}"
# shellcheck source=scripts/release/toolchain-policy.sh
source "$PROJECT_DIR/scripts/release/toolchain-policy.sh"

OUTPUT_DIR="${QUILNODE_OPENSSL_TOOLCHAIN_DIR:-$(quilnode_default_openssl_toolchain "$WORKSPACE_DIR")}"
ARCHIVE_URL="https://github.com/openssl/openssl/releases/download/openssl-$QUILNODE_OPENSSL_VERSION/openssl-$QUILNODE_OPENSSL_VERSION.tar.gz"

if [[ -r "$OUTPUT_DIR/include/openssl/evp.h" && -r "$OUTPUT_DIR/lib/libcrypto.a" ]]; then
    actual_version="$("$OUTPUT_DIR/bin/openssl" version | awk '{print $2}')"
    [[ "$actual_version" == "$QUILNODE_OPENSSL_VERSION" ]] || {
        echo "Existing OpenSSL toolchain has unexpected version $actual_version" >&2
        exit 1
    }
    if strings -a "$OUTPUT_DIR/lib/libcrypto.a" | rg -q \
        "(/Users/|/home/|/private/var/folders/|$WORKSPACE_DIR|$PROJECT_DIR)"; then
        echo "Existing OpenSSL toolchain contains build-machine paths." >&2
        exit 1
    fi
    strings -a "$OUTPUT_DIR/lib/libcrypto.a" | rg -q --fixed-strings "$QUILNODE_OPENSSL_NEUTRAL_PREFIX"
    echo "$OUTPUT_DIR"
    exit 0
fi
if [[ -e "$OUTPUT_DIR" ]]; then
    echo "Refusing to overwrite an incomplete toolchain directory: $OUTPUT_DIR" >&2
    exit 1
fi

build_root="$(mktemp -d -t quilnode-openssl-build)"
trap 'rm -rf "$build_root"' EXIT
archive="$build_root/openssl-$QUILNODE_OPENSSL_VERSION.tar.gz"
curl --fail --silent --show-error --location --proto '=https' --tlsv1.2 \
    --output "$archive" "$ARCHIVE_URL"
actual_sha256="$(shasum -a 256 "$archive" | awk '{print $1}')"
[[ "$actual_sha256" == "$QUILNODE_OPENSSL_SHA256" ]] || {
    echo "OpenSSL source checksum mismatch." >&2
    exit 1
}

tar -xzf "$archive" -C "$build_root"
source_dir="$build_root/openssl-$QUILNODE_OPENSSL_VERSION"
staging_root="$build_root/install-root"
cd "$source_dir"
export MACOSX_DEPLOYMENT_TARGET=14.0
export SOURCE_DATE_EPOCH=0
export ZERO_AR_DATE=1
CC="$(xcrun -f clang)"
export CC
SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
export SDKROOT
export CFLAGS="-isysroot $SDKROOT"
export LDFLAGS="-isysroot $SDKROOT"
./Configure darwin64-arm64-cc \
    no-shared no-module no-pinshared no-tests no-docs no-legacy \
    --prefix="$QUILNODE_OPENSSL_NEUTRAL_PREFIX" \
    --openssldir="$QUILNODE_OPENSSL_NEUTRAL_PREFIX/ssl" \
    --libdir=lib
build_log="$build_root/build.log"
if ! make -j"$(sysctl -n hw.logicalcpu)" > "$build_log" 2>&1; then
    tail -n 200 "$build_log" >&2
    exit 1
fi
if ! make install_sw DESTDIR="$staging_root" >> "$build_log" 2>&1; then
    tail -n 200 "$build_log" >&2
    exit 1
fi

installed_tree="$staging_root$QUILNODE_OPENSSL_NEUTRAL_PREFIX"
[[ -r "$installed_tree/include/openssl/evp.h" && -r "$installed_tree/lib/libcrypto.a" ]]
mkdir -p "$(dirname "$OUTPUT_DIR")"
ditto --norsrc --noextattr --noqtn "$installed_tree" "$OUTPUT_DIR"

[[ -r "$OUTPUT_DIR/include/openssl/evp.h" && -r "$OUTPUT_DIR/lib/libcrypto.a" ]]
[[ "$("$OUTPUT_DIR/bin/openssl" version | awk '{print $2}')" == "$QUILNODE_OPENSSL_VERSION" ]]
if strings -a "$OUTPUT_DIR/lib/libcrypto.a" | rg -q \
    "(/Users/|/home/|/private/var/folders/|$build_root|$WORKSPACE_DIR|$PROJECT_DIR)"; then
    echo "The OpenSSL toolchain contains build-machine paths." >&2
    exit 1
fi
strings -a "$OUTPUT_DIR/lib/libcrypto.a" | rg -q --fixed-strings "$QUILNODE_OPENSSL_NEUTRAL_PREFIX"
echo "$OUTPUT_DIR"
