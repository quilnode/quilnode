#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/release/toolchain-policy.sh
source "$PROJECT_DIR/scripts/release/toolchain-policy.sh"
OPENSSL_PREFIX="${QUILNODE_OPENSSL_PREFIX:-}"
if [[ -z "$OPENSSL_PREFIX" ]]; then
    WORKSPACE_DIR="${QUILNODE_WORKSPACE_DIR:-$(cd "$PROJECT_DIR/.." && pwd)/workspace}"
    OPENSSL_PREFIX="$(quilnode_default_openssl_toolchain "$WORKSPACE_DIR")"
fi
OPENSSL="$OPENSSL_PREFIX/bin/openssl"
if [[ ! -x "$OPENSSL" || ! -r "$OPENSSL_PREFIX/lib/libcrypto.a" ]]; then
    echo "OpenSSL 3 development files are required for verifier tests." >&2
    exit 1
fi

TEST_DIR="$(mktemp -d)"
VERIFIER="$TEST_DIR/QuilNodeReleaseVerifier"
xcrun clang \
    -O2 -g0 -Wall -Wextra -Werror \
    -ffile-prefix-map="$PROJECT_DIR=/usr/src/quilnode" \
    -fdebug-prefix-map="$PROJECT_DIR=/usr/src/quilnode" \
    -fmacro-prefix-map="$PROJECT_DIR=/usr/src/quilnode" \
    -target arm64-apple-macos14.0 \
    -I"$OPENSSL_PREFIX/include" \
    "$PROJECT_DIR/Sources/QuilNodeReleaseVerifier/main.c" \
    "$OPENSSL_PREFIX/lib/libcrypto.a" \
    -framework Security -framework CoreFoundation \
    -o "$VERIFIER" 2>"$TEST_DIR/build.log"

printf 'QuilNode release verifier fixture\n' > "$TEST_DIR/payload"
COMPUTED="$($VERIFIER sha3-256 "$TEST_DIR/payload")"
REFERENCE="$($OPENSSL dgst -sha3-256 "$TEST_DIR/payload" | sed 's/^.*= //')"
test "$COMPUTED" = "$REFERENCE"

# The verifier must ignore hostile caller-controlled OpenSSL configuration and
# provider search paths. It uses only the statically linked built-in provider.
printf '%s\n' 'openssl_conf = broken' '[broken]' 'providers = missing' \
    > "$TEST_DIR/hostile-openssl.cnf"
poisoned="$({
    OPENSSL_CONF="$TEST_DIR/hostile-openssl.cnf" \
    OPENSSL_MODULES="$TEST_DIR/missing-modules" \
    "$VERIFIER" sha3-256 "$TEST_DIR/payload"
})"
test "$poisoned" = "$REFERENCE"

$OPENSSL genpkey -algorithm ED448 -out "$TEST_DIR/private.pem" >/dev/null 2>&1
$OPENSSL pkey -in "$TEST_DIR/private.pem" -pubout -outform DER \
    -out "$TEST_DIR/public.der" >/dev/null 2>&1
tail -c 57 "$TEST_DIR/public.der" | xxd -p -c 114 > "$TEST_DIR/public.hex"
printf 'SHA3-256(payload)= %s\n' "$COMPUTED" > "$TEST_DIR/payload.dgst"
$OPENSSL pkeyutl -sign -rawin -inkey "$TEST_DIR/private.pem" \
    -in "$TEST_DIR/payload.dgst" -out "$TEST_DIR/payload.sig"

PUBLIC_KEY="$(tr -d '\n' < "$TEST_DIR/public.hex")"
$VERIFIER verify-ed448 "$PUBLIC_KEY" "$TEST_DIR/payload.sig" "$TEST_DIR/payload.dgst"
printf 'tampered\n' >> "$TEST_DIR/payload.dgst"
if $VERIFIER verify-ed448 "$PUBLIC_KEY" "$TEST_DIR/payload.sig" "$TEST_DIR/payload.dgst"; then
    echo "The verifier accepted a tampered Ed448 message." >&2
    exit 1
fi

ln -s "$TEST_DIR/payload" "$TEST_DIR/payload-link"
if $VERIFIER sha3-256 "$TEST_DIR/payload-link" >/dev/null 2>&1; then
    echo "The verifier followed a symbolic link." >&2
    exit 1
fi

printf 'hard-link fixture\n' > "$TEST_DIR/hard-link-source"
ln "$TEST_DIR/hard-link-source" "$TEST_DIR/hard-link-copy"
if $VERIFIER sha3-256 "$TEST_DIR/hard-link-source" >/dev/null 2>&1; then
    echo "The verifier accepted a multiply linked input." >&2
    exit 1
fi

mkfifo "$TEST_DIR/input-fifo"
if "$VERIFIER" sha3-256 "$TEST_DIR/input-fifo" >/dev/null 2>&1; then
    echo "The verifier accepted a FIFO input." >&2
    exit 1
fi

SANITIZED_VERIFIER="$TEST_DIR/QuilNodeReleaseVerifier-sanitized"
xcrun clang \
    -O1 -g -Wall -Wextra -Werror \
    -fsanitize=address,undefined -fno-omit-frame-pointer \
    -target arm64-apple-macos14.0 \
    -I"$OPENSSL_PREFIX/include" \
    "$PROJECT_DIR/Sources/QuilNodeReleaseVerifier/main.c" \
    "$OPENSSL_PREFIX/lib/libcrypto.a" \
    -framework Security -framework CoreFoundation \
    -o "$SANITIZED_VERIFIER"

for malformed_key in "" "00" "zz$(printf '%0112d' 0)" "$(printf '%0116d' 0)"; do
    if "$SANITIZED_VERIFIER" verify-ed448 "$malformed_key" \
        "$TEST_DIR/payload.sig" "$TEST_DIR/payload.dgst" >/dev/null 2>&1; then
        echo "The sanitized verifier accepted malformed public-key input." >&2
        exit 1
    fi
done
for length in 0 1 55 56 57 113 114 115 255 256 257 8191 8192 8193; do
    dd if=/dev/zero of="$TEST_DIR/fuzz-$length" bs=1 count="$length" status=none
    "$SANITIZED_VERIFIER" sha3-256 "$TEST_DIR/fuzz-$length" >/dev/null
    if "$SANITIZED_VERIFIER" verify-ed448 "$PUBLIC_KEY" \
        "$TEST_DIR/fuzz-$length" "$TEST_DIR/payload.dgst" >/dev/null 2>&1; then
        echo "The sanitized verifier accepted malformed signature length $length." >&2
        exit 1
    fi
done

echo "PASS: SHA3-256, Ed448, tamper rejection, link/FIFO defenses, and sanitizer boundary cases"
