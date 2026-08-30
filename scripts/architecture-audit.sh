#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

failures=0
fail() {
    echo "FAIL: $*" >&2
    failures=$((failures + 1))
}

expected_source_roots=(
    QuilNodeApp
    QuilNodeCore
    QuilNodeHelperCLI
    QuilNodeHelperKit
    QuilNodeProbe
    QuilNodeReleaseVerifier
    QuilNodeShared
)
expected_test_roots=(
    QuilNodeAppTests
    QuilNodeCoreTests
    QuilNodeHelperKitTests
    QuilNodeSharedTests
)

for source_root in Sources/*; do
    [[ -d "$source_root" ]] || continue
    source_name="${source_root#Sources/}"
    if [[ ! " ${expected_source_roots[*]} " =~ " ${source_name} " ]]; then
        fail "undeclared or orphaned source root is present: $source_root"
    fi
done
for test_root in Tests/*; do
    [[ -d "$test_root" ]] || continue
    test_name="${test_root#Tests/}"
    if [[ ! " ${expected_test_roots[*]} " =~ " ${test_name} " ]]; then
        fail "undeclared or orphaned test root is present: $test_root"
    fi
done

if ! rg -q 'Sources/QuilNodeReleaseVerifier/main\.c' scripts/build-app.sh; then
    fail "the manually compiled release-verifier source is not declared by the release build"
fi

required_directories=(
    Sources/QuilNodeApp/Application
    Sources/QuilNodeApp/Dashboard
    Sources/QuilNodeApp/DesignSystem
    Sources/QuilNodeApp/Features
    Sources/QuilNodeApp/Infrastructure
    Sources/QuilNodeApp/Features/Updates/Coordination
    Sources/QuilNodeApp/Features/Updates/Discovery
    Sources/QuilNodeApp/Features/Updates/Infrastructure
    Sources/QuilNodeApp/Features/Updates/Models
    Sources/QuilNodeApp/Features/Updates/Persistence
    Sources/QuilNodeApp/Features/Updates/Staging
    Sources/QuilNodeApp/Features/Updates/Views/Dashboard
    Sources/QuilNodeApp/Features/Wallet/Infrastructure
    Sources/QuilNodeApp/Features/Wallet/Models
    Sources/QuilNodeApp/Features/Wallet/IdentityTransaction/Presentation
    Sources/QuilNodeApp/Features/Wallet/IdentityTransaction/Views
    Sources/QuilNodeApp/Dashboard/Overview
    Sources/QuilNodeApp/DesignSystem/Theme/BuiltIns
    Sources/QuilNodeApp/DesignSystem/Theme/Loading
    Sources/QuilNodeCore/Domain
    Sources/QuilNodeCore/Infrastructure
    Sources/QuilNodeCore/Infrastructure/Parsing/Node
    Sources/QuilNodeShared/Application
    Sources/QuilNodeShared/IPC
    Sources/QuilNodeShared/Theme/Legacy
    Sources/QuilNodeShared/Theme/Pack
    Sources/QuilNodeHelperKit/Application
    Sources/QuilNodeHelperKit/Infrastructure
    Sources/QuilNodeHelperCLI
    Tests/QuilNodeCoreTests/TestSupport
    Tests/QuilNodeAppTests
    Tests/QuilNodeSharedTests
    Tests/QuilNodeHelperKitTests
)
for directory in "${required_directories[@]}"; do
    [[ -d "$directory" ]] || fail "required architecture directory is missing: $directory"
done

for feature_path in Sources/QuilNodeApp/Features/*; do
    [[ -d "$feature_path" ]] || continue
    while IFS= read -r source; do
        [[ -z "$source" ]] || fail "feature source must live in a responsibility folder: $source"
    done < <(find "$feature_path" -maxdepth 1 -type f -name '*.swift' -print)
done

while IFS= read -r test_source; do
    [[ -z "$test_source" ]] || fail "feature test must live with its feature suite: $test_source"
done < <(find Tests/QuilNodeAppTests/Features -maxdepth 1 -type f -name '*.swift' -print)

for target in QuilNodeApp QuilNodeCore QuilNodeShared QuilNodeHelperKit; do
    while IFS= read -r source; do
        [[ -z "$source" ]] || fail "Swift source must live in a responsibility folder: $source"
    done < <(find "Sources/$target" -maxdepth 1 -type f -name '*.swift' -print)
done

if [[ -d Sources/QuilNodeSelfTests ]] || rg -q 'quilnode-self-tests|QuilNodeSelfTests' Package.swift project.yml 2>/dev/null; then
    fail "the retired top-level self-test executable is present"
fi

if rg -n '^import QuilNode(App|Helper)' Sources/QuilNodeCore Sources/QuilNodeShared; then
    fail "Core or Shared imports a higher-level executable module"
fi
if rg -n '^import QuilNode(Core|App|Helper)' Sources/QuilNodeShared; then
    fail "Shared imports another QuilNode module"
fi
if rg -n '^import QuilNode(App|Core)' Sources/QuilNodeHelperKit; then
    fail "the privileged helper imports an unprivileged implementation module"
fi
if rg -n '^import (AppKit|Charts|SwiftUI)$' \
    Sources/QuilNodeCore Sources/QuilNodeShared Sources/QuilNodeHelperKit; then
    fail "non-UI modules must not depend on app presentation frameworks"
fi
if rg -n '^import XCTest$' Sources; then
    fail "production sources must not import the test framework"
fi

wire_contract='Sources/QuilNodeShared/IPC/PrivilegedServiceProtocol.swift'
if [[ ! -f "$wire_contract" ]] ||
   ! rg -q 'enum PrivilegedServiceAction' "$wire_contract" ||
   ! rg -q 'struct PrivilegedServiceRequest' "$wire_contract" ||
   ! rg -q 'struct PrivilegedServiceResponse' "$wire_contract"; then
    fail "the privileged IPC contract is not centralized in QuilNodeShared"
fi
if rg -n '^(public )?(enum Privileged(Node|Service)Action|struct Privileged(Node|Service)(Request|Response)|enum ServiceAction|struct Service(Request|Response))' \
    Sources/QuilNodeCore Sources/QuilNodeHelperKit; then
    fail "the app and helper must consume, not redeclare, the shared IPC wire contract"
fi

wallet_wire_contract='Sources/QuilNodeShared/IPC/WalletServiceProtocol.swift'
if [[ ! -f "$wallet_wire_contract" ]] ||
   ! rg -q 'public struct WalletInventory' "$wallet_wire_contract" ||
   ! rg -q 'public struct WalletTransactionManifest' "$wallet_wire_contract"; then
    fail "the wallet service wire contract is not centralized in QuilNodeShared"
fi
if rg -n '^(public )?(struct (WalletInventory|WalletTransactionManifest)|enum WalletTransactionKind)' \
    Sources/QuilNodeCore Sources/QuilNodeHelperKit; then
    fail "Core and HelperKit must consume, not redeclare, the shared wallet wire contract"
fi

if ! rg -q '\.target\(name: "QuilNodeShared"' Package.swift ||
   ! rg -q '\.target\(name: "QuilNodeCore", dependencies: \["QuilNodeShared"\]\)' Package.swift ||
   ! rg -q '\.target\(name: "QuilNodeHelperKit", dependencies: \["QuilNodeShared"\]\)' Package.swift ||
   ! rg -q '\.executableTarget\(name: "QuilNodeHelperCLI", dependencies: \["QuilNodeHelperKit"\]\)' Package.swift ||
   ! rg -q 'name: "QuilNodeAppTests"' Package.swift ||
   ! rg -q '\.testTarget\(name: "QuilNodeSharedTests"' Package.swift ||
   ! rg -q 'name: "QuilNodeHelperKitTests"' Package.swift; then
    fail "Swift Package module or XCTest boundaries are incomplete"
fi
if ! rg -q '^  QuilNodeShared:' project.yml ||
   ! rg -q '^  QuilNodeCore:' project.yml ||
   ! rg -q '^  QuilNodeHelperKit:' project.yml ||
   ! rg -q '^  QuilNodeHelperCLI:' project.yml ||
   ! rg -q 'target: QuilNodeCore' project.yml ||
   ! rg -q 'target: QuilNodeShared' project.yml; then
    fail "Xcode target dependencies do not mirror the Swift Package boundaries"
fi

helper_entry='Sources/QuilNodeHelperCLI/QuilNodeHelperMain.swift'
helper_entry_lines="$(wc -l < "$helper_entry" | tr -d ' ')"
if (( helper_entry_lines > 20 )) ||
   ! rg -q 'QuilNodeHelper\.run\(\)' "$helper_entry"; then
    fail "the root helper executable must remain a tiny composition entry point"
fi

source_build_orchestrator='Sources/QuilNodeApp/Features/Updates/Staging/SourceBuildStaging.swift'
required_source_build_phases=(
    SourceBuildCheckoutStaging.swift
    SourceBuildCompilationStaging.swift
    SourceBuildQClientStaging.swift
    SourceBuildPlanSealing.swift
)
for phase in "${required_source_build_phases[@]}"; do
    [[ -f "Sources/QuilNodeApp/Features/Updates/Staging/$phase" ]] ||
        fail "source-build pipeline phase is missing: $phase"
done
if rg -q 'runChecked|FileManager|SourceBuildSandbox' "$source_build_orchestrator"; then
    fail "the source-build facade must orchestrate phases rather than perform infrastructure work"
fi

while IFS=$'\t' read -r line_count source; do
    [[ -z "$source" ]] && continue
    if (( line_count > 375 )); then
        fail "production Swift file exceeds the 375-line review budget ($line_count): $source"
    fi
done < <(find Sources -type f -name '*.swift' -print0 | xargs -0 wc -l | awk 'NF == 2 && $2 != "total" { print $1 "\t" $2 }')

while IFS=$'\t' read -r line_count source; do
    [[ -z "$source" ]] && continue
    if (( line_count > 350 )); then
        fail "test Swift file exceeds 350 lines ($line_count): $source"
    fi
done < <(find Tests -type f -name '*.swift' -print0 | xargs -0 wc -l | awk 'NF == 2 && $2 != "total" { print $1 "\t" $2 }')

if find Sources Tests -type f \( -name '*.legacy.swift' -o -name '*~' -o -name '*.bak' \) -print -quit | grep -q .; then
    fail "legacy or editor-backup source files remain in the codebase"
fi

# A named SwiftUI view with no reference beyond its declaration is inert
# redesign residue: it compiles, inflates the public source surface, and can
# quietly diverge from the component that actually ships. Root scene types
# conform to `App` rather than `View`, so every named View must have a caller.
while IFS= read -r view_type; do
    [[ -z "$view_type" ]] && continue
    reference_count="$(
        rg -w -o "$view_type" Sources/QuilNodeApp Tests/QuilNodeAppTests --glob '*.swift' \
            | wc -l \
            | tr -d ' '
    )"
    if (( reference_count < 2 )); then
        fail "SwiftUI view has no reachable caller: $view_type"
    fi
done < <(
    rg -N -o \
        '^(private |fileprivate |internal )?struct [A-Za-z_][A-Za-z0-9_]*(<[^>]+>)?: View' \
        Sources/QuilNodeApp --glob '*.swift' \
        | sed -E 's/.*struct ([A-Za-z_][A-Za-z0-9_]*).*/\1/' \
        | sort -u
)

# Dashboard composition frequently lives in computed view properties on
# `DashboardView` extensions. Unlike named View types, an abandoned property
# can compile forever without any reachable caller. Reject declaration-only
# properties so a redesign cannot leave an inert screen graph behind.
while IFS= read -r view_property; do
    [[ -z "$view_property" || "$view_property" == "body" ]] && continue
    reference_count="$(
        rg -w -o "$view_property" Sources/QuilNodeApp Tests/QuilNodeAppTests --glob '*.swift' \
            | wc -l \
            | tr -d ' '
    )"
    if (( reference_count < 2 )); then
        fail "computed SwiftUI view has no reachable caller: $view_property"
    fi
done < <(
    rg -N -o \
        '^\s*(private |fileprivate )?var [A-Za-z_][A-Za-z0-9_]*: some View' \
        Sources/QuilNodeApp --glob '*.swift' \
        | sed -E 's/.*var ([A-Za-z_][A-Za-z0-9_]*):.*/\1/' \
        | sort -u
)

for target_path in Sources/* Tests/*; do
    [[ -d "$target_path" ]] || continue
    duplicate_names="$({ find "$target_path" -type f -name '*.swift' -exec basename {} \;; } | sort | uniq -d)"
    [[ -z "$duplicate_names" ]] ||
        fail "duplicate Swift basenames in ${target_path#*/}: ${duplicate_names//$'\n'/, }"
done

# The project is developed and shipped on case-insensitive macOS volumes. Two
# basenames that differ only by case are ambiguous in reviews and can collide
# when a checkout moves between filesystems, even if Git records both objects.
for target_path in Sources/* Tests/*; do
    [[ -d "$target_path" ]] || continue
    case_collisions="$({ find "$target_path" -type f -name '*.swift' -exec basename {} \;; } \
        | awk '{ print tolower($0) }' | sort | uniq -d)"
    [[ -z "$case_collisions" ]] ||
        fail "case-insensitive Swift basename collision in ${target_path#*/}: ${case_collisions//$'\n'/, }"
done

if rg -n '^public ' Sources/QuilNodeHelperKit --glob '!**/Application/QuilNodeHelper.swift'; then
    fail "the privileged implementation exposes public API outside its single runtime facade"
fi

if (( failures > 0 )); then
    echo "Architecture audit failed with $failures issue(s)." >&2
    exit 1
fi

echo "PASS: source layout, dependency direction, platform boundaries, and maintainability limits"
