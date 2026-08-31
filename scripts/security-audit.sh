#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

scripts/architecture-audit.sh

failures=0

for forbidden in .config/config.yml .config/keys.yml Resources/qclient Resources/QuilNodeLocalSigning.cer; do
    if [[ -e "$forbidden" || -L "$forbidden" ]]; then
        echo "FAIL: sensitive or machine-local artifact exists inside the public repository: $forbidden" >&2
        failures=$((failures + 1))
    fi
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1 && git ls-files --error-unmatch "$forbidden" >/dev/null 2>&1; then
        echo "FAIL: sensitive or machine-local artifact is tracked: $forbidden" >&2
        failures=$((failures + 1))
    fi
done

if rg -n --hidden \
    --glob '!.git/**' --glob '!.build/**' --glob '!dist/**' --glob '!Audit/**' --glob '!.config/**' --glob '!Resources/qclient' --glob '!scripts/security-audit.sh' \
    '(BEGIN (RSA|OPENSSH|EC|DSA) PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|github_pat_|AKIA[0-9A-Z]{16}|xox[baprs]-|AIza[0-9A-Za-z_-]{20,}|sk-[A-Za-z0-9]{20,})' .; then
    echo "FAIL: possible credential material found" >&2
    failures=$((failures + 1))
fi

if [[ ! -r Resources/QuilNodeReleaseSigning.cer ]]; then
    echo "FAIL: public project release certificate is missing" >&2
    failures=$((failures + 1))
fi
if [[ ! -r LICENSE || ! -r NOTICE.md ]]; then
    echo "FAIL: public license or independent-project notice is missing" >&2
    failures=$((failures + 1))
fi
if ! rg -q 'GNU AFFERO GENERAL PUBLIC LICENSE' LICENSE ||
   ! rg -q 'independent, unofficial community project' README.md NOTICE.md; then
    echo "FAIL: AGPL or independent-project disclosure is incomplete" >&2
    failures=$((failures + 1))
fi
if ! rg -q 'exact: "2\.9\.6"' Package.swift ||
   ! rg -q 'exactVersion: 2\.9\.6' project.yml ||
   ! rg -q 'SURequireSignedFeed.*true' project.yml ||
   ! rg -q 'SUVerifyUpdateBeforeExtraction.*true' project.yml ||
   ! rg -q 'SUAllowsAutomaticUpdates.*false' project.yml ||
   ! rg -q 'SUEnableSystemProfiling.*false' project.yml ||
   ! rg -q 'SUSignedFeedFailureExpirationInterval: 0' project.yml; then
    echo "FAIL: exact Sparkle pin or fail-closed updater policy is missing" >&2
    failures=$((failures + 1))
fi
if [[ "$(/usr/libexec/PlistBuddy -c 'Print :com.apple.security.cs.disable-library-validation' Resources/QuilNode.entitlements 2>/dev/null)" != "true" ]] ||
   rg -n 'com\.apple\.security\.cs\.(allow-dyld-environment-variables|allow-jit|allow-unsigned-executable-memory|disable-executable-page-protection|get-task-allow)' Resources/QuilNode.entitlements; then
    echo "FAIL: community-signed Sparkle profile has an unexpected hardened-runtime exception" >&2
    failures=$((failures + 1))
fi
if rg -n 'DJIxXBjq/gVQx7fUypBouvqtsS1Qx7SKvBUAi/yKZp8=' \
    --glob '!Resources/Info.plist' --glob '!project.yml' \
    --glob '!scripts/release/release-common.sh' --glob '!scripts/security-audit.sh' .; then
    echo "FAIL: update public key is duplicated outside its approved trust declarations" >&2
    failures=$((failures + 1))
fi
if rg -n 'QuilNode Local Code Signing|QuilNodeLocalSigning\.cer' \
    Sources project.yml Resources/Info.plist; then
    echo "FAIL: machine-local signing identity remains in release code" >&2
    failures=$((failures + 1))
fi

# Operator telemetry that once appeared in local test fixtures is a public
# fingerprint even though it is not credential material. Keep these exact
# historical values out of every publishable source and resource.
if rg -n '(2c2dccb6a835ac4e|13219200|13224570|13224580)' \
    Sources Resources README.md PRIVACY.md SECURITY.md CONTRIBUTING.md NOTICE.md; then
    echo "FAIL: known operator telemetry is present in the public candidate" >&2
    failures=$((failures + 1))
fi

if rg -n \
    '(Data\(contentsOf:|String\(contentsOf:|FileHandle\(forReadingFrom:|copyItem\().*(config\.yml|keys\.yml)|(config\.yml|keys\.yml).*(Data\(contentsOf:|String\(contentsOf:|FileHandle\(forReadingFrom:|copyItem\()' \
    Sources/QuilNodeApp Sources/QuilNodeCore Sources/QuilNodeShared; then
    echo "FAIL: unprivileged targets contain key-file byte access" >&2
    failures=$((failures + 1))
fi

if rg -n '(privateKey:|peerPrivKey:|encryptionKey:)' Sources/QuilNodeApp Sources/QuilNodeCore Sources/QuilNodeShared; then
    echo "FAIL: unprivileged targets contain private-key schema parsing" >&2
    failures=$((failures + 1))
fi

if rg -n '/opt/homebrew/bin/openssl|/usr/local/bin/openssl' Sources/QuilNodeApp Sources/QuilNodeCore Sources/QuilNodeShared; then
    echo "FAIL: production app targets depend on an external OpenSSL executable" >&2
    failures=$((failures + 1))
fi

if find Resources -type f -name qclient -print -quit | grep -q .; then
    echo "FAIL: qclient is embedded in public application resources" >&2
    failures=$((failures + 1))
fi

if rg -n '/Applications/QuilNode\.app/Contents/Resources/qclient|/usr/local/bin/qclient' Sources; then
    echo "FAIL: qclient execution depends on an app-bundle or PATH-style location" >&2
    failures=$((failures + 1))
fi

# Allocation and shard counts are screenshot-sensitive. They must enter the UI
# as structured values classified by PrivacyField, never as interpolated prose
# that can bypass Privacy Mode in a subtitle, tooltip, or notification.
if rg -n '\\\([^)]*(activeShards|pendingJoins|totalAllocations)' Sources/QuilNodeApp; then
    echo "FAIL: allocation or shard count bypasses the structured privacy boundary" >&2
    failures=$((failures + 1))
fi

if rg -n 'isSensitive' Sources/QuilNodeApp; then
    echo "FAIL: legacy boolean privacy classification remains in the UI" >&2
    failures=$((failures + 1))
fi

verified_install_calls="$(rg -o 'installVerifiedNodeCandidate\(manifest, stage: stage\)' Sources/QuilNodeHelperKit | wc -l | tr -d ' ')"
if [[ "${verified_install_calls:-0}" -lt 2 ]] ||
   ! rg -q 'try verifySignedRelease\(manifest, stage: stage\)' Sources/QuilNodeHelperKit ||
   ! rg -q 'try verifySignedRelease\(manifest, stage: nodeDirectory\)' Sources/QuilNodeHelperKit ||
   ! rg -q 'ReleaseTrustPolicy\.minimumSignatures' Sources/QuilNodeHelperKit ||
   ! rg -q 'operatorVerifier' Sources/QuilNodeHelperKit; then
    echo "FAIL: staged and root-owned signed-release verification invariant is missing" >&2
    failures=$((failures + 1))
fi

if ! rg -q 'static func trustedQClient\(\)' Sources/QuilNodeHelperKit ||
   ! rg -q 'verifyOfficialArtifact\(manifest\.qclient' Sources/QuilNodeHelperKit ||
   ! rg -q 'stage: releaseDirectory' Sources/QuilNodeHelperKit ||
   ! rg -q 'runAsServiceUser\(' Sources/QuilNodeHelperKit ||
   ! rg -q 'qclientRecordURL' Sources/QuilNodeHelperKit; then
    echo "FAIL: managed qclient provenance or root re-verification invariant is missing" >&2
    failures=$((failures + 1))
fi

if ! rg -q 'O_RDONLY \| O_CLOEXEC \| O_NOFOLLOW \| O_NONBLOCK' Sources/QuilNodeHelperKit ||
   ! rg -q 'before\.st_nlink == 1' Sources/QuilNodeHelperKit ||
   ! rg -q 'static func withMutationLock' Sources/QuilNodeHelperKit ||
   ! rg -q 'acquireInProcessMutationLock\(until: deadline\)' Sources/QuilNodeHelperKit ||
   ! rg -q 'flock\(descriptor, LOCK_EX \| LOCK_NB\) == 0' Sources/QuilNodeHelperKit; then
    echo "FAIL: descriptor-safe input or cross-process mutation lock invariant is missing" >&2
    failures=$((failures + 1))
fi

if ! rg -q 'authorizationRequired\(' Sources/QuilNodeHelperKit ||
   ! rg -q 'Installing a source-built node requires explicit macOS administrator approval' Sources/QuilNodeHelperKit ||
   ! rg -q 'Installing a source-built qclient requires explicit macOS administrator approval' Sources/QuilNodeHelperKit ||
   ! rg -q 'Identity creation, import, activation, and recovery export require explicit macOS administrator approval' Sources/QuilNodeHelperKit; then
    echo "FAIL: fresh authorization gates for untrusted code or identity mutations are missing" >&2
    failures=$((failures + 1))
fi

if ! rg -q 'currentServiceBuild = 115' Sources/QuilNodeShared/IPC/PrivilegedServiceProtocol.swift ||
   ! rg -q 'minimumSupportedServiceBuild = 115' Sources/QuilNodeShared/IPC/PrivilegedServiceProtocol.swift ||
   ! rg -q 'PrivilegedServiceProtocol\.minimumSupportedServiceBuild' Sources/QuilNodeCore/Infrastructure/IPC/PrivilegedServiceClient.swift ||
   [[ "$(rg -o 'serviceBuild: verifierReady \? PrivilegedServiceProtocol\.currentServiceBuild : nil' Sources/QuilNodeHelperKit | wc -l | tr -d ' ')" -ne 1 ]]; then
    echo "FAIL: privileged service compatibility floor is inconsistent" >&2
    failures=$((failures + 1))
fi

if ! rg -q 'nodeUpdatePolicyURL' Sources/QuilNodeHelperKit ||
   ! rg -q 'requiredOwner: 0' Sources/QuilNodeHelperKit/Node/AutomaticNodeUpdateAuthorization.swift ||
   ! rg -q 'mode: 0o600' Sources/QuilNodeHelperKit/Node/AutomaticNodeUpdateAuthorization.swift ||
   ! rg -q 'permitsPasswordlessActivation' Sources/QuilNodeShared/Release/AutomaticNodeUpdatePolicy.swift ||
   ! rg -q 'allowsInteractiveAuthorization: false' Sources/QuilNodeApp/Features/Updates/Coordination/ReleaseCheckerInstallation.swift; then
    echo "FAIL: channel-scoped automatic update authorization is incomplete" >&2
    failures=$((failures + 1))
fi

if ! rg -q 'verifyProjectSignedComponent' Sources/QuilNodeHelperKit ||
   [[ "$(rg -o 'certificateDigest: signingDigest' Sources/QuilNodeHelperKit | wc -l | tr -d ' ')" -lt 2 ]]; then
    echo "FAIL: copied privileged components are not re-verified against the pinned certificate" >&2
    failures=$((failures + 1))
fi

if ! rg -q 'mkdirat\(' Sources/QuilNodeHelperKit ||
   ! rg -q 'openat\(' Sources/QuilNodeHelperKit ||
   ! rg -q 'O_RDWR \| O_CREAT \| O_EXCL \| O_NOFOLLOW \| O_CLOEXEC' Sources/QuilNodeHelperKit; then
    echo "FAIL: recovery export is missing descriptor-relative exclusive creation" >&2
    failures=$((failures + 1))
fi

if ! rg -q '\(deny default\)' Sources/QuilNodeCore/Infrastructure/Security/SourceBuildSandbox.swift ||
   ! rg -q '\(deny network\*\)' Sources/QuilNodeCore/Infrastructure/Security/SourceBuildSandbox.swift ||
   ! rg -q 'arguments: \["fetch", "--locked"\]' Sources/QuilNodeApp/Features/Updates ||
   ! rg -q 'verifyPinnedCheckoutIsUnmodified' Sources/QuilNodeApp/Features/Updates; then
    echo "FAIL: deny-by-default source build isolation invariant is missing" >&2
    failures=$((failures + 1))
fi

if ! rg -q 'runArtifactVersionProbe\(' Sources/QuilNodeHelperKit ||
   ! rg -q '/usr/bin/sandbox-exec' Sources/QuilNodeHelperKit ||
   ! rg -q '\(deny network\*\)' Sources/QuilNodeHelperKit; then
    echo "FAIL: installed artifact runtime probing is not restricted and network-denied" >&2
    failures=$((failures + 1))
fi

if rg -n 'runChecked\((binary|staged)\.path' Sources/QuilNodeApp/Features/Updates; then
    echo "FAIL: the GUI directly executes a downloaded candidate" >&2
    failures=$((failures + 1))
fi

if ! rg -q 'BoundedCommandRunner\.run' Sources/QuilNodeCore/Infrastructure/Network/NetworkLocalInspector.swift ||
   ! rg -q 'BoundedCommandRunner\.run' Sources/QuilNodeCore/Infrastructure/Node/LocalNodeCollector+Runtime.swift ||
   ! rg -q 'BoundedCommandRunner\.run' Sources/QuilNodeApp/Infrastructure/Node/NodeLifecycleController.swift ||
   ! rg -q 'BoundedCommandRunner\.run' Sources/QuilNodeApp/Features/Installation/Infrastructure/InstallationHostInspector.swift ||
   ! rg -q 'maximumOutputBytes' Sources/QuilNodeCore/Infrastructure/Process/BoundedCommandRunner.swift; then
    echo "FAIL: local subprocesses are missing centralized timeout/output bounds" >&2
    failures=$((failures + 1))
fi

# Output quotas belong on stdout/stderr, never on the entire subprocess. An
# inherited RLIMIT_FSIZE silently truncates legitimate Git packs and compiler
# artifacts even when their console output is small.
if rg -n 'ulimit -f|RLIMIT_FSIZE|setrlimit\(' Sources; then
    echo "FAIL: a console-output guard applies an inherited process-wide file-size limit" >&2
    failures=$((failures + 1))
fi
if ! rg -q 'BoundedProcessOutputPump' Sources/QuilNodeApp/Features/Updates/Infrastructure/BoundedProcessExecution.swift ||
   ! rg -q 'BoundedProcessOutputPump' Sources/QuilNodeCore/Infrastructure/Process/BoundedCommandRunner.swift ||
   ! rg -q 'BoundedProcessOutputPump' Sources/QuilNodeHelperKit/Infrastructure/CommandExecution.swift; then
    echo "FAIL: subprocess output is not consistently isolated through the bounded pipe pump" >&2
    failures=$((failures + 1))
fi

if ! rg -q 'BoundedFileDownloadDelegate' Sources/QuilNodeApp/Features/Updates ||
   ! rg -q 'BoundedDataDownloadDelegate' Sources/QuilNodeApp/Features/Updates ||
   ! rg -q 'totalBytesWritten > maximumBytes' Sources/QuilNodeApp/Features/Updates ||
   ! rg -q 'completionHandler\(nil\)' Sources/QuilNodeApp/Features/Updates; then
    echo "FAIL: update downloads are missing in-flight size and redirect enforcement" >&2
    failures=$((failures + 1))
fi

if ! rg -q 'O_RDONLY \| O_CLOEXEC \| O_NOFOLLOW \| O_NONBLOCK' Sources/QuilNodeShared/FileSystem/BoundedLocalData.swift ||
   ! rg -q 'BoundedLocalData\.read' Sources/QuilNodeApp/Infrastructure/Persistence/NodeHistoryStore.swift ||
   [[ "$(rg -o 'BoundedLocalData\.read' Sources/QuilNodeApp/Features/Updates | wc -l | tr -d ' ')" -lt 4 ]]; then
    echo "FAIL: local UI state is missing bounded no-follow reads" >&2
    failures=$((failures + 1))
fi

if ! rg -q 'openat\(' Sources/QuilNodeShared/FileSystem/TrustedLocalFile.swift ||
   ! rg -q 'renameat\(' Sources/QuilNodeShared/FileSystem/PrivateLocalFileSystem.swift ||
   ! rg -q 'O_WRONLY \| O_CREAT \| O_EXCL \| O_NOFOLLOW \| O_CLOEXEC \| O_NONBLOCK' \
        Sources/QuilNodeShared/FileSystem/PrivateLocalFileSystem.swift ||
   ! rg -q 'TrustedLocalFile\.read' Sources/QuilNodeApp/Features/Updates/Infrastructure/UpdateStorage.swift ||
   ! rg -q 'PrivateLocalFileSystem\.write' \
        Sources/QuilNodeApp/Features/Wallet/Infrastructure/WalletTransactionStaging.swift ||
   ! rg -q 'transactionStaging\.makeDirectory' \
        Sources/QuilNodeApp/Features/Wallet/Coordination/WalletManager.swift ||
   ! rg -q 'transactionStaging\.write' \
        Sources/QuilNodeApp/Features/Wallet/Coordination/WalletManager.swift; then
    echo "FAIL: descriptor-relative recovery reads or private atomic state writes are missing" >&2
    failures=$((failures + 1))
fi

if ! rg -q 'catch HelperFailure\.unauthorized' Sources/QuilNodeHelperKit/Service/PrivilegedServiceServer.swift ||
   ! rg -q 'serviceUser: nil' Sources/QuilNodeHelperKit/Service/PrivilegedServiceServer.swift ||
   ! rg -q 'serviceBuild: nil' Sources/QuilNodeHelperKit/Service/PrivilegedServiceServer.swift ||
   [[ "$(rg -o 'throw HelperFailure\.unauthorized' Sources/QuilNodeHelperKit/Service | wc -l | tr -d ' ')" -lt 8 ]]; then
    echo "FAIL: unauthenticated service responses can expose privileged runtime state" >&2
    failures=$((failures + 1))
fi

if ! rg -q 'manifestAge >= -300' Sources/QuilNodeHelperKit/Node/NodeStageValidation.swift ||
   ! rg -q 'manifestAge >= -300' Sources/QuilNodeHelperKit/Wallet/WalletTransactions.swift ||
   ! rg -q 'timeIntervalSince\(manifest\.createdAt\) >= -300' Sources/QuilNodeHelperKit/QClient/QClientOperations.swift; then
    echo "FAIL: signed transaction manifests do not reject excessive future clock skew" >&2
    failures=$((failures + 1))
fi

helper_hash_source="$(
    rg -l 'static func sha256\(_ url: URL\)' \
        Sources/QuilNodeHelperKit/Infrastructure --glob '*.swift' || true
)"
helper_hash_source_count="$(printf '%s\n' "$helper_hash_source" | sed '/^$/d' | wc -l | tr -d ' ')"
helper_hash_function=""
if [[ "$helper_hash_source_count" -eq 1 ]]; then
    helper_hash_function="$(
        sed -n '/static func sha256(_ url: URL)/,/static func sha256(_ data: Data)/p' \
            "$helper_hash_source"
    )"
fi
if [[ "$helper_hash_source_count" -ne 1 ]] ||
   ! printf '%s' "$helper_hash_function" | rg -q 'O_RDONLY \| O_CLOEXEC \| O_NOFOLLOW \| O_NONBLOCK' ||
   ! printf '%s' "$helper_hash_function" | rg -q 'before\.st_ino == after\.st_ino' ||
   ! printf '%s' "$helper_hash_function" | rg -q 'before\.st_mtimespec\.tv_nsec == after\.st_mtimespec\.tv_nsec' ||
   printf '%s' "$helper_hash_function" | rg -q 'FileHandle\(forReadingFrom:'; then
    echo "FAIL: privileged artifact hashing is not descriptor-bound and mutation-aware" >&2
    failures=$((failures + 1))
fi

migration_backup="$(sed -n '/static func createMigrationBackup/,/static func prepareRuntimeOwnership/p' Sources/QuilNodeHelperKit/Service/RuntimeMigration.swift)"
if ! printf '%s' "$migration_backup" | rg -q 'readSecureRegularFile' ||
   printf '%s' "$migration_backup" | rg -q 'copyItem'; then
    echo "FAIL: legacy identity migration backup uses a path-based sensitive copy" >&2
    failures=$((failures + 1))
fi

if [[ ! -x scripts/release/audit-app-bundle.sh ]] ||
   [[ ! -x scripts/release/build-openssl-toolchain.sh ]] ||
   [[ ! -x scripts/release/audit-metadata-privacy.sh ]] ||
   [[ ! -x scripts/release/test-metadata-privacy.sh ]] ||
   ! rg -q 'quilnode_default_openssl_toolchain' scripts/build-app.sh scripts/test-release-verifier.sh ||
   ! rg -q 'QUILNODE_OPENSSL_VERSION="3\.5\.8"' scripts/release/toolchain-policy.sh ||
   ! rg -q 'openssl-3\.5\.8-macos14-arm64-neutral-v2' scripts/release/toolchain-policy.sh ||
   ! rg -q 'QUILNODE_OPENSSL_NEUTRAL_PREFIX="/opt/quilnode/toolchains/openssl/3\.5\.8"' scripts/release/toolchain-policy.sh ||
   ! rg -q 'a8f84a39918ec6415ce765d9b429d313ba97b8143169c172e734b9514464f5b2' scripts/release/toolchain-policy.sh ||
   ! rg -q 'no-shared no-module no-pinshared' scripts/release/build-openssl-toolchain.sh ||
   ! rg -q 'OPENSSL_INIT_NO_LOAD_CONFIG' Sources/QuilNodeReleaseVerifier/main.c ||
   ! rg -q 'hostile-openssl\.cnf' scripts/test-release-verifier.sh ||
   ! rg -q 'QuilNodeLocalSigning\.cer' scripts/release/audit-app-bundle.sh ||
   ! rg -q 'audit-metadata-privacy\.sh.*artifact' scripts/release/audit-app-bundle.sh ||
   ! rg -q 'audit-metadata-privacy\.sh.*repository' scripts/release/security-preflight.sh ||
   ! rg -q 'audit-metadata-privacy\.sh.*artifact' scripts/release/prepare-release.sh scripts/release/verify-release.sh; then
    echo "FAIL: reproducible verifier toolchain or signed-bundle audit gate is missing" >&2
    failures=$((failures + 1))
fi

if ! rg -q 'PRODUCT_BUNDLE_IDENTIFIER: com\.quilnode\.app' project.yml ||
   ! rg -q 'permanentAppIdentifier = "com\.quilnode\.app"' Sources/QuilNodeHelperKit ||
   ! rg -q 'permanent-app-identity-v1' Sources/QuilNodeHelperKit; then
    echo "FAIL: permanent application identity or legacy-identity bridge is missing" >&2
    failures=$((failures + 1))
fi

if rg -n 'expandSeniorityTable|mainnet_seniority-' Sources; then
    echo "FAIL: a reconstructed seniority dataset can bypass immutable Git LFS provenance" >&2
    failures=$((failures + 1))
fi
if ! rg -q 'GitLFSPointerParser\.parse' Sources/QuilNodeApp/Features/Updates ||
   ! rg -q 'media\.githubusercontent\.com/media/QuilibriumNetwork/monorepo/' Sources/QuilNodeApp/Features/Updates ||
   ! rg -q 'verifyPinnedCheckoutIsUnmodified' Sources/QuilNodeApp/Features/Updates; then
    echo "FAIL: exact source builds do not enforce committed Git LFS inputs" >&2
    failures=$((failures + 1))
fi

if (( failures > 0 )); then
    exit 1
fi

echo "PASS: repository secret exclusions and GUI key-boundary checks"
