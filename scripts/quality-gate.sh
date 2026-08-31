#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

scripts/architecture-audit.sh
xcrun swift-format lint --recursive --strict --configuration .swift-format Sources Tests
swift test --parallel
scripts/check-helper-composition.sh
scripts/security-audit.sh
scripts/release/test-metadata-privacy.sh
scripts/release/test-evidence.sh
scripts/release/audit-metadata-privacy.sh repository .
semgrep scan --config config/security/semgrep.yml \
    --metrics off --error --exclude .build --exclude Audit Sources scripts

echo "PASS: architecture, formatting, tests, privacy metadata, and repository security boundaries"
