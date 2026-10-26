import Foundation
import XCTest

@testable import QuilNodeApp
@testable import QuilNodeCore

final class OperatorValuePresentationTests: XCTestCase {
    func testAmountsKeepExactDecimalAndSignalPrecisionLoss() {
        let locale = Locale(identifier: "en_US")
        let amount = TokenAmountPresentation("1234.592313103750", locale: locale)
        XCTAssertEqual(amount.exact, "1234.59231310375")
        XCTAssertEqual(amount.compact, "≈1,234.592313")
        XCTAssertTrue(amount.isApproximate)
        XCTAssertEqual(TokenAmountPresentation("0.000000000001", locale: locale).compact, "<0.000001")
        XCTAssertEqual(TokenAmountPresentation("0000.000000", locale: locale).compact, "0")
        XCTAssertEqual(TokenAmountPresentation("42.500000", locale: locale).compact, "42.5")
        let large = "340282366920938463463374607.431768211455"
        XCTAssertEqual(TokenAmountPresentation(large, locale: locale).exact, large)
        XCTAssertEqual(
            TokenAmountPresentation(large, locale: locale).compact, "≈340,282,366,920,938,463,463,374,607.431768")
        XCTAssertEqual(
            TokenAmountPresentation("0.59231310375", locale: Locale(identifier: "fr_FR")).compact, "≈0,592313")
        for invalid: String? in [nil, "", "-1", "NaN", "1e2", "1.2.3", "1,000", "١٢"] {
            XCTAssertNil(TokenAmountPresentation(invalid).exact)
            XCTAssertEqual(TokenAmountPresentation(invalid).compact, "—")
        }
    }

    func testOldAndMissingObservationsNeverLookCurrent() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertFalse(ObservationFreshness(observedAt: nil, now: now).isCurrent)
        XCTAssertFalse(ObservationFreshness(observedAt: now.addingTimeInterval(-121), now: now).isCurrent)
        XCTAssertFalse(ObservationFreshness(observedAt: now.addingTimeInterval(60), now: now).isCurrent)
        XCTAssertEqual(ObservationFreshness(observedAt: now.addingTimeInterval(-61), now: now).label, "Read 1m ago")
    }

    func testWorkerAttentionUsesCurrentExecutionRatherThanAssignment() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let blocked = WorkerExecutionObservation(
            state: "blocked", blocker: "checkpoint mismatch", observedAt: now, readAt: now)
        let current = WorkerExecutionPresentation(observation: blocked, nodeRunning: true, now: now)
        XCTAssertEqual(current.title, "Blocked")
        XCTAssertTrue(current.needsReview)
        XCTAssertFalse(
            WorkerExecutionPresentation(observation: blocked, nodeRunning: true, now: now.addingTimeInterval(121))
                .needsReview)
        XCTAssertFalse(WorkerExecutionPresentation(observation: blocked, nodeRunning: false, now: now).needsReview)
        let running = WorkerExecutionObservation(state: "running", observedAt: now, readAt: now)
        XCTAssertEqual(
            WorkerExecutionPresentation(observation: running, nodeRunning: true, now: now).title, "Host running")
        XCTAssertEqual(WorkerExecutionPresentation(observation: nil, nodeRunning: true, now: now).title, "Not reported")
    }

    func testFrameAdvanceAgeIsIndependentFromTheReadTime() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let observation = WorkerExecutionObservation(
            state: "serve", lastAdvanceAt: now.addingTimeInterval(-2_460), observedAt: now, readAt: now)
        let presentation = WorkerExecutionPresentation(observation: observation, nodeRunning: true, now: now)
        XCTAssertEqual(presentation.title, "Serving")
        XCTAssertEqual(presentation.advanceText, "41m ago")
        XCTAssertEqual(
            WorkerExecutionPresentation(observation: nil, nodeRunning: true, now: now).advanceText, "Not reported")
    }
}
