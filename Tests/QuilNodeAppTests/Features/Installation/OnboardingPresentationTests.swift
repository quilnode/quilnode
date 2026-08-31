import XCTest

@testable import QuilNodeApp
@testable import QuilNodeCore

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
    }
}
