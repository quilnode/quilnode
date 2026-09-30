#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AUDITOR="$PROJECT_DIR/scripts/release/audit-metadata-privacy.sh"
fixture_root="$(mktemp -d -t quilnode-metadata-audit)"
trap 'rm -rf "$fixture_root"' EXIT

clean="$fixture_root/clean"
mkdir -p "$clean"
printf 'QuilNode public artifact\n' > "$clean/manifest.txt"
xattr -cr "$clean"
"$AUDITOR" artifact "$clean" >/dev/null

path_leak="$fixture_root/path-leak"
mkdir -p "$path_leak"
printf '/Users/private-builder/work/QuilNode\n' > "$path_leak/binary-fixture"
xattr -cr "$path_leak"
if "$AUDITOR" artifact "$path_leak" >/dev/null 2>&1; then
    echo "Metadata auditor accepted a concrete home-directory path." >&2
    exit 1
fi

# An early match in a large stream must still fail under pipefail; quiet
# consumers can otherwise SIGPIPE their producer and hide a positive result.
awk 'BEGIN { for (i = 0; i < 20000; i++) print "public padding for a large artifact" }' >> "$path_leak/binary-fixture"
if "$AUDITOR" artifact "$path_leak" >/dev/null 2>&1; then
    echo "Metadata auditor accepted an early path leak in a large artifact." >&2
    exit 1
fi

xattr_leak="$fixture_root/xattr-leak"
mkdir -p "$xattr_leak"
printf 'clean bytes\n' > "$xattr_leak/file"
xattr -cr "$xattr_leak"
xattr -w com.quilnode.metadata-test present "$xattr_leak/file"
if "$AUDITOR" artifact "$xattr_leak" >/dev/null 2>&1; then
    echo "Metadata auditor accepted an extended attribute." >&2
    exit 1
fi

echo "PASS: metadata auditor accepts clean artifacts and rejects paths and xattrs"
