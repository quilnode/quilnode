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
