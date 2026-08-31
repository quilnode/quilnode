import XCTest

@testable import QuilNodeApp
@testable import QuilNodeCore
@testable import QuilNodeShared

final class OnboardingPresentationTests: XCTestCase {
    func testJourneyCollapsesDependenciesIntoFourOperatorOutcomes() {
        XCTAssertEqual(OnboardingStage.allCases.map(\.title), ["This Mac", "Runtime", "Identity", "Network"])
        XCTAssertEqual(OnboardingStage.current(for: .inspecting), .host)
        XCTAssertEqual(OnboardingStage.current(for: .verifying), .runtime)
        XCTAssertEqual(OnboardingStage.current(for: .awaitingAuthorization), .runtime)
        XCTAssertEqual(OnboardingStage.current(for: .validating), .runtime)
    }

    func testDetectedIdentityIsTheOnlyAutomaticChoice() {
        XCTAssertEqual(IdentityOnboardingChoice.initialChoice(hasActiveIdentity: true), .keep)
        XCTAssertNil(IdentityOnboardingChoice.initialChoice(hasActiveIdentity: false))
        XCTAssertEqual(IdentityOnboardingChoice.importKeyset.primaryActionTitle, "Choose keyset…")
    }

    func testFirstInstallMakesExistingIdentityImportExplicit() {
        XCTAssertEqual(FirstInstallIdentityPlan.allCases, [.createNew, .importExisting])
        XCTAssertEqual(FirstInstallIdentityPlan.createNew.preferredIdentityChoice, .create)
        XCTAssertEqual(FirstInstallIdentityPlan.importExisting.preferredIdentityChoice, .importKeyset)
        XCTAssertEqual(
            IdentityOnboardingChoice.initialChoice(
                hasActiveIdentity: true,
                preferredChoice: .importKeyset
            ),
            .importKeyset
        )
    }

    func testExternalNodeDiscoveryBlocksOnlyUnmanagedRuntimeProcesses() {
        let processTable = """
            /Applications/QuilNode.app/Contents/MacOS/QuilNode
            /opt/quilibrium/node/quilibrium-node
            /Users/operator/ceremonyclient/node/node-2.1.0.25-darwin-arm64
            /usr/local/bin/node
            """
        XCTAssertTrue(ExistingNodeRuntimeDiscovery.isExternalNodeRunning(processTable: processTable))

        let managedOnly = """
            /opt/quilibrium/node/quilibrium-node
            /usr/local/bin/node
            """
        XCTAssertFalse(ExistingNodeRuntimeDiscovery.isExternalNodeRunning(processTable: managedOnly))
    }

    func testRuntimeProgressUsesNamedFiniteStepsInsteadOfOpaquePercentageAlone() {
        XCTAssertEqual(
            OnboardingRuntimeProgress.firstInstall(phase: .downloading),
            .init(step: 2, total: 6, title: "Acquire signed artifacts")
        )
        XCTAssertEqual(
            OnboardingRuntimeProgress.firstInstall(phase: .complete),
            .init(step: 6, total: 6, title: "Validate local health")
        )
        XCTAssertEqual(
            OnboardingRuntimeProgress.qclient(phase: .installing),
            .init(step: 4, total: 4, title: "Install & re-check")
        )

        let failedBuild = NodeUpdateProgress(
            workflow: .qclient,
            step: .client,
            phase: "Compiler stopped",
            detail: "Build failed",
            fraction: 0.4,
            startedAt: Date()
        )
        XCTAssertEqual(
            OnboardingRuntimeProgress.qclient(phase: .failed, progress: failedBuild),
            .init(step: 2, total: 4, title: "Acquire or build client")
        )
    }

    func testPrivilegedQClientStagesRemainVisibleAndDeterministic() {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let progress = InstallationOperationPresentation.progress(
            for: .init(
                stage: .probingRuntime,
                message: "Checking the qclient runtime version (up to 15 seconds)."
            ),
            workflow: .qclient,
            startedAt: startedAt
        )

        XCTAssertEqual(progress.phase, "Checking runtime version")
        XCTAssertEqual(progress.detail, "Checking the qclient runtime version (up to 15 seconds).")
        XCTAssertEqual(progress.fraction, 0.98)
        XCTAssertEqual(progress.startedAt, startedAt)
        XCTAssertEqual(
            InstallationOperationPresentation.elapsedDescription(
                from: startedAt,
                to: startedAt.addingTimeInterval(74)
            ),
            "Elapsed 1m 14s"
        )
    }

    func testOnlySourceBuiltQClientPermitsInteractiveFallback() {
        let manifest = URL(fileURLWithPath: "/private/tmp/qclient-install.json")
        let official = PreparedQClientAsset(
            officialRelease: OfficialQClientRelease(
                releaseVersion: "2.1.0.23",
                binaryFileName: "qclient-2.1.0.23-darwin-arm64",
                digestPublished: true,
                signatureIndices: [1, 2, 8, 11, 13, 14, 17]
            ),
            manifestURL: manifest
        )
        let source = PreparedQClientAsset(officialRelease: nil, manifestURL: manifest)

        XCTAssertFalse(official.allowsInteractiveAuthorization)
        XCTAssertTrue(source.allowsInteractiveAuthorization)
    }
}
