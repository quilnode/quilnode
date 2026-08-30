import XCTest

@testable import QuilNodeApp
@testable import QuilNodeCore

final class OperatorInterlockPresentationTests: XCTestCase {
    func testRestartExplainsProcessChangeAndDurableBoundary() {
        let model = OperatorInterlockPresentation.lifecycle(.restart)

        XCTAssertEqual(model.steps.map(\.title), ["Pause service", "Resume service", "Verify telemetry"])
        XCTAssertTrue(model.changes.contains { $0.id == "process" })
        XCTAssertEqual(Set(model.preserved.map(\.id)), ["identity", "stores", "configuration", "binary"])
        XCTAssertTrue(model.verification.contains("Process running"))
        XCTAssertEqual(model.defaultDecision.actionTitle, "Restart node")
    }

    func testStopStatesThatParticipationPausesWithoutDeletingData() {
        let model = OperatorInterlockPresentation.lifecycle(.stop)

        XCTAssertEqual(model.tone, .destructive)
        XCTAssertTrue(model.changes.contains { $0.id == "participation" })
        XCTAssertTrue(model.preserved.contains { $0.id == "stores" })
        XCTAssertTrue(model.trustNote.localizedCaseInsensitiveContains("does not delete"))
    }

    func testFirewallRepairKeepsRouterOutsideTheBoundary() {
        let model = OperatorInterlockPresentation.diagnostic(.configureFirewall)

        XCTAssertTrue(model.changes.contains { $0.id == "binary-rule" })
        XCTAssertTrue(model.preserved.contains { $0.id == "router" })
        XCTAssertTrue(model.verification.contains("Router untouched"))
        XCTAssertTrue(model.trustNote.localizedCaseInsensitiveContains("password"))
    }

    func testApprovedDevelopmentPolicyOffersNowAndLaterWithoutBroadeningScope() {
        let model = OperatorInterlockPresentation.updatePolicy(.approvedDevelopment)

        XCTAssertEqual(model.decisions.map(\.id), ["now", "later"])
        XCTAssertEqual(model.defaultDecisionID, "now")
        XCTAssertTrue(model.outcome.localizedCaseInsensitiveContains("exact commit"))
        XCTAssertTrue(model.trustNote.localizedCaseInsensitiveContains("unmarked"))
        XCTAssertTrue(model.preserved.contains { $0.id == "identity" })
        XCTAssertTrue(model.preserved.contains { $0.id == "rollback" })
    }

    func testSignedAndRawPoliciesUseTruthfulTrustLanguage() {
        let signed = OperatorInterlockPresentation.updatePolicy(.signedStable)
        let raw = OperatorInterlockPresentation.updatePolicy(.bleedingEdge)

        XCTAssertTrue(signed.outcome.localizedCaseInsensitiveContains("Ed448"))
        XCTAssertTrue(signed.verification.contains("Signature quorum passes"))
        XCTAssertTrue(raw.outcome.localizedCaseInsensitiveContains("raw commit"))
        XCTAssertTrue(raw.trustNote.localizedCaseInsensitiveContains("high risk"))
    }

    func testQuitDuringUpdatePreservesTheManagedNode() {
        let model = OperatorInterlockPresentation.quitDuringUpdate

        XCTAssertEqual(model.cancelTitle, "Keep Running")
        XCTAssertEqual(model.defaultDecision.actionTitle, "Quit anyway")
        XCTAssertTrue(model.preserved.contains { $0.id == "service-state" })
        XCTAssertTrue(model.verification.contains("Installed node retained"))
    }
}
