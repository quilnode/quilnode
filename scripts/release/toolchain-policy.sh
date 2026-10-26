#!/usr/bin/env bash

# Shared, non-secret release-toolchain policy. Keep builder locations separate
# from the neutral paths compiled into artifacts so no operator home directory
# can become part of a public binary.
# shellcheck disable=SC2034 # Constants are consumed by scripts that source this policy.
readonly QUILNODE_OPENSSL_VERSION="4.1.0"
readonly QUILNODE_OPENSSL_SHA256="50c17baf54cb008f6ce42d50deb4b28050a1aad711636cabd4b241c7e90cc2fd"
readonly QUILNODE_OPENSSL_TOOLCHAIN_ID="openssl-4.1.0-macos14-arm64-neutral-v2"
readonly QUILNODE_OPENSSL_NEUTRAL_PREFIX="/opt/quilnode/toolchains/openssl/4.1.0"

quilnode_default_openssl_toolchain() {
    local workspace_dir="$1"
    printf '%s/%s\n' "$workspace_dir/toolchains" "$QUILNODE_OPENSSL_TOOLCHAIN_ID"
}
