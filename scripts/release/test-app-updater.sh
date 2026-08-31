#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$PROJECT_DIR"
REPORT_DIR="${1:?Usage: test-app-updater.sh /absolute/report-directory}"
[[ "$REPORT_DIR" == /* ]] || { echo 'Report directory must be absolute.' >&2; exit 64; }
mkdir -p "$REPORT_DIR"
chmod 700 "$REPORT_DIR"

# Resolve the exact locked package; this does not install or launch the app.
swift package resolve
resolved_framework="$PROJECT_DIR/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
[[ -d "$resolved_framework" ]] || {
    echo 'The resolved Sparkle binary framework is missing.' >&2; exit 1;
}
build_dir="$(mktemp -d "${TMPDIR:-/tmp}/quilnode-updater-build.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT
framework_root="$build_dir/frameworks"
mkdir -p "$framework_root"
# launchd's installer must not execute from a privacy-protected source folder
# (for example Documents). Keep the exact resolved framework in this test root.
ditto "$resolved_framework" "$framework_root/Sparkle.framework"
xcrun swiftc -swift-version 6 -O -o "$build_dir/runner" \
    -F "$framework_root" -framework Sparkle -Xlinker -rpath -Xlinker "$framework_root" \
    Sources/QuilNodeApp/Application/AppVersion.swift \
    Sources/QuilNodeApp/Features/Updates/Models/AppUpdatePhase.swift \
    Sources/QuilNodeApp/Features/Updates/Models/AppUpdateOutcome.swift \
    Sources/QuilNodeApp/Features/Updates/Coordination/AppUpdateController.swift \
    scripts/release/qualification/QualificationUserDriver.swift \
    scripts/release/qualification/main.swift
xcrun swiftc -O scripts/release/tests/sign-fixture.swift -o "$build_dir/sign-fixture"
xcrun clang scripts/release/qualification/fixture.c -o "$build_dir/fixture"
python3 scripts/release/qualification/run.py \
    --runner "$build_dir/runner" --signer "$build_dir/sign-fixture" \
    --executable "$build_dir/fixture" --info Resources/Info.plist --report "$REPORT_DIR"
