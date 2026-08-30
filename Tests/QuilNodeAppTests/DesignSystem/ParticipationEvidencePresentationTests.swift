import XCTest

@testable import QuilNodeApp
@testable import QuilNodeCore

final class ParticipationEvidencePresentationTests: XCTestCase {
    func testActiveAllocationAndRewardEvidenceRemainSeparate() {
        let presentation = ParticipationEvidencePresentation.make(
            snapshot: NodeSnapshot(
                isRunning: true,
                pendingJoins: 2,
                activeShards: 5,
                totalAllocations: 7
            )
        )

        XCTAssertEqual(presentation.state, .activeAllocations)
        XCTAssertEqual(presentation.title, "Allocations active")
        XCTAssertEqual(presentation.rewardState, .noCreditObserved)
        XCTAssertEqual(presentation.rewardTitle, "No credit observed")
        XCTAssertFalse(presentation.title.localizedCaseInsensitiveContains("proving"))
        XCTAssertFalse(presentation.rewardTitle.localizedCaseInsensitiveContains("pending"))
    }

    func testObservedCreditIsOnlyClaimedFromExplicitCreditEvidence() {
        let presentation = ParticipationEvidencePresentation.make(
            snapshot: NodeSnapshot(
                isRunning: true,
                lastRewardCreditFrame: 766_000,
                activeShards: 5,
                totalAllocations: 5
            )
        )

        XCTAssertEqual(presentation.rewardState, .creditObserved)
        XCTAssertEqual(presentation.rewardTitle, "Credit observed")
        XCTAssertTrue(presentation.rewardDetail.contains("766"))
    }
}
