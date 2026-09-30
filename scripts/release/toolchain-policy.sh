#!/usr/bin/env bash

# Shared, non-secret release-toolchain policy. Keep builder locations separate
# from the neutral paths compiled into artifacts so no operator home directory
# can become part of a public binary.
# shellcheck disable=SC2034 # Constants are consumed by scripts that source this policy.
readonly QUILNODE_OPENSSL_VERSION="3.5.9"
readonly QUILNODE_OPENSSL_SHA256="603f5602e2eef00d77fbd429d34dcd5822bb301757a1bc9cdb24c670f1eb859a"
readonly QUILNODE_OPENSSL_TOOLCHAIN_ID="openssl-3.5.9-macos14-arm64-neutral-v2"
readonly QUILNODE_OPENSSL_NEUTRAL_PREFIX="/opt/quilnode/toolchains/openssl/3.5.9"

quilnode_default_openssl_toolchain() {
    local workspace_dir="$1"
    printf '%s/%s\n' "$workspace_dir/toolchains" "$QUILNODE_OPENSSL_TOOLCHAIN_ID"
}
