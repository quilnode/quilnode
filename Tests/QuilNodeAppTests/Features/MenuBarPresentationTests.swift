import Foundation
import XCTest

@testable import QuilNodeApp
@testable import QuilNodeCore

final class MenuBarPresentationTests: XCTestCase {
    func testActiveProverSeparatesParticipationFromRewardOutcome() {
        let presentation = MenuBarPresentation(
            snapshot: NodeSnapshot(
                isRunning: true,
                lastReceivedFrame: 753_568,
                epoch: 1_046,
                epochLength: 720,
                frame: 753_568,
                activeShards: 9,
                framesPerMinute: 6
            ),
            phase: .ready
        )

        XCTAssertEqual(presentation.participationTitle, "Prover Active")
        XCTAssertEqual(presentation.participationSummary, "Participating and syncing")
        XCTAssertEqual(
            presentation.rewardSummary,
            "Rewards pending — proving does not guarantee payment"
        )
    }

    func testOrdinaryDistantMilestoneDoesNotOccupyCompactPanel() {
        let snapshot = NodeSnapshot(isRunning: true, frame: 100, framesPerMinute: 6)
        let notice = MenuBarMilestonePresentation.resolve(
            milestones: [milestone(targetFrame: 10_000)],
            snapshot: snapshot,
            now: Date(timeIntervalSince1970: 2_000_000_000)
        )

        XCTAssertNil(notice)
    }

    func testImminentMilestoneBecomesTemporaryActivityDestination() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let notice = MenuBarMilestonePresentation.resolve(
            milestones: [milestone(targetFrame: 754_000)],
            snapshot: NodeSnapshot(
                isRunning: true,
                frame: 753_568,
                framesPerMinute: 6
            ),
            now: now
        )

        XCTAssertEqual(notice?.title, "QUIL Prover Reset V4")
        XCTAssertEqual(notice?.detail, "432 frames until target \(UInt64(754_000).grouped).")
        XCTAssertEqual(notice?.tone, .attention)
    }

    func testMissingSupportOverridesDistanceAndRequestsAttention() {
        var unsupported = milestone(targetFrame: 10_000)
        unsupported.installedSupport = .missing

        let notice = MenuBarMilestonePresentation.resolve(
            milestones: [unsupported],
            snapshot: NodeSnapshot(isRunning: true, frame: 100),
            now: Date(timeIntervalSince1970: 2_000_000_000)
        )

        XCTAssertEqual(notice?.title, "Protocol support missing")
        XCTAssertEqual(notice?.tone, .danger)
    }

    func testCompletedMilestoneLeavesCompactPanelAfterOneEpoch() {
        let notice = MenuBarMilestonePresentation.resolve(
            milestones: [milestone(targetFrame: 1_000)],
            snapshot: NodeSnapshot(isRunning: true, frame: 1_721),
            now: Date(timeIntervalSince1970: 2_000_000_000)
        )

        XCTAssertNil(notice)
    }

    private func milestone(targetFrame: UInt64) -> ProtocolMilestone {
        ProtocolMilestone(
            symbol: "QUIL_PROVER_RESET_V4_FRAME",
            title: "QUIL Prover Reset V4",
            kind: .reset,
            targetFrame: targetFrame,
            summary: "Scheduled protocol event.",
            operatorImpact: "No manual action is normally required.",
            sourcePath: "crates/node/src/main.rs",
            sourceLine: 1,
            branch: "develop",
            commit: "test",
            committedAt: Date(timeIntervalSince1970: 2_000_000_000),
            checkedAt: Date(timeIntervalSince1970: 2_000_000_000),
            installedSupport: .included
        )
    }
}
