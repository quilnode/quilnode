#!/usr/bin/env bash
set -euo pipefail

# One fail-closed, local release-security gate. `audit` validates a dirty
# development tree without accessing the offline update key. `release` also
# requires committed/tagged source and exercises the separately held Ed25519
# update identity before producing the final release directory.
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKSPACE_DIR="${QUILNODE_WORKSPACE_DIR:-$(cd "$PROJECT_DIR/.." && pwd)/workspace}"
MODE="${1:-audit}"
case "$MODE" in audit|release) ;; *) echo "Usage: $0 [audit|release]" >&2; exit 64 ;; esac

timestamp="$(date -u +%Y%m%dT%H%M%SZ)"
REPORT_DIR="${QUILNODE_SECURITY_REPORT_DIR:-$WORKSPACE_DIR/audits/security-preflight-$timestamp}"
mkdir -p "$REPORT_DIR"
chmod 700 "$REPORT_DIR"
cd "$PROJECT_DIR"

for command_name in swift xcodebuild xcodegen shellcheck gitleaks osv-scanner syft codesign semgrep trivy; do
    command -v "$command_name" >/dev/null 2>&1 || {
        echo "Missing mandatory security tool: $command_name" >&2
        exit 1
    }
done

run_gate() {
    local name="$1"
    shift
    echo "==> $name"
    "$@" 2>&1 | tee "$REPORT_DIR/$name.log"
}

if [[ "$MODE" == "release" ]]; then
    [[ -z "$(git status --porcelain)" ]] || {
        echo "Release preflight requires a clean committed tree." >&2
        exit 1
    }
    git describe --tags --exact-match >/dev/null 2>&1 || {
        echo "Release preflight requires an exact immutable version tag." >&2
        exit 1
    }
    [[ -n "${QUILNODE_UPDATE_KEY_PASSWORD_FILE:-}" && -r "$QUILNODE_UPDATE_KEY_PASSWORD_FILE" ]] || {
        echo "Release preflight requires the separately held update-key password file." >&2
        exit 1
    }
fi

run_gate repository-boundaries scripts/security-audit.sh
run_gate swift-format xcrun swift-format lint --recursive --strict \
    --configuration .swift-format Sources Tests
run_gate static-security-rules semgrep scan --config config/security/semgrep.yml \
    --metrics off --error --exclude .build --exclude Audit Sources scripts

shell_scripts=()
while IFS= read -r script; do shell_scripts+=("$script"); done < <(find scripts -type f -name '*.sh' -print | sort)
run_gate shellcheck shellcheck -x "${shell_scripts[@]}"

run_gate secret-scan gitleaks dir --no-banner --no-color --redact=100 \
    --config .gitleaks.toml --report-format json --report-path "$REPORT_DIR/gitleaks.json" .
run_gate history-secret-scan gitleaks git --no-banner --no-color --redact=100 \
    --log-opts="--all --full-history" --config .gitleaks.toml \
    --report-format json --report-path "$REPORT_DIR/gitleaks-history.json" .
run_gate repository-metadata scripts/release/audit-metadata-privacy.sh repository .
run_gate metadata-auditor-tests scripts/release/test-metadata-privacy.sh
run_gate release-evidence-tests scripts/release/test-evidence.sh
run_gate dependency-vulnerabilities osv-scanner scan source --recursive \
    --experimental-exclude .build --experimental-exclude Audit \
    --format json --output-file "$REPORT_DIR/osv.json" .
run_gate filesystem-security trivy fs --scanners vuln,secret,misconfig \
    --skip-dirs .build --skip-dirs Audit --exit-code 1 \
    --format json --output "$REPORT_DIR/trivy.json" .
app_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
run_gate sbom syft scan "dir:$PROJECT_DIR" \
    --exclude './.build/**' --exclude './Audit/**' \
    --source-name QuilNode --source-version "$app_version" \
    --output "cyclonedx-json=$REPORT_DIR/sbom.cdx.json"

run_gate swift-debug swift build -c debug
run_gate parser-and-boundary-tests swift test --parallel
run_gate swift-address-sanitizer swift test --sanitize=address --parallel
run_gate swift-thread-sanitizer swift test --sanitize=thread --parallel
run_gate swift-release-warnings swift build -c release -Xswiftc -warnings-as-errors
run_gate release-verifier scripts/test-release-verifier.sh

run_gate xcode-project xcodegen generate --spec project.yml --project "$PROJECT_DIR"
run_gate xcode-static-analyzer xcodebuild \
    -project QuilNode.xcodeproj -scheme QuilNode -configuration Release \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath .build/xcode-analyze \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES analyze
run_gate xcode-helper-static-analyzer xcodebuild \
    -project QuilNode.xcodeproj -scheme QuilNodeHelper -configuration Release \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath .build/xcode-analyze-helper \
    CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
    SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES analyze

run_gate signed-application scripts/build-app.sh
APP_PATH="$WORKSPACE_DIR/artifacts/app-builds/QuilNode.app"
run_gate sealed-bundle scripts/release/audit-app-bundle.sh \
    "$APP_PATH" "${QUILNODE_SIGNING_NAME:-QuilNode Project Release Signing}"

if [[ "$MODE" == "release" ]]; then
    run_gate update-key-tamper scripts/release/test-update-signing.sh
    release_root="$(scripts/release/prepare-release.sh | tee "$REPORT_DIR/prepare-release.log" | tail -1)"
    [[ -d "$release_root" ]] || { echo "Release packaging did not return a directory." >&2; exit 1; }
    run_gate archive-feed-tamper scripts/release/test-release-tamper.sh "$release_root"
    printf '%s\n' "$release_root" > "$REPORT_DIR/release-path.txt"
fi

{
    echo "QuilNode security preflight"
    echo "Mode: $MODE"
    echo "Completed UTC: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "Application: $APP_PATH"
    echo "Result: PASS"
} > "$REPORT_DIR/SUMMARY.txt"
chmod 600 "$REPORT_DIR"/* 2>/dev/null || true
echo "PASS: $REPORT_DIR"
