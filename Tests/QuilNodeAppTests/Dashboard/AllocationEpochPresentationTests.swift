import XCTest

@testable import QuilNodeApp
@testable import QuilNodeCore

final class AllocationEpochPresentationTests: XCTestCase {
    func testConfirmedJoinExplainsActivationInsteadOfClaimingActive() throws {
        let allocation = ShardAllocation(index: 0, filter: "aa", status: "joining", confirmFrame: 800)
        let cell = AllocationCellPresentation(allocation: allocation)
        XCTAssertEqual(cell.lifecycle, .joining)
        XCTAssertEqual(cell.lifecycleLabel, "Confirmed · waiting")
        let timing = try XCTUnwrap(
            AllocationEpochPresentation(allocation: allocation, clock: .init(frame: 1000, epochLength: 720)))
        XCTAssertEqual(timing.label, "Activation epoch")
        XCTAssertEqual(timing.value, "2")
        XCTAssertTrue(timing.explanation.contains("not reward evidence"))
    }

    func testCLIExpirySpellingGetsAnExplicitAttentionState() {
        for status in ["expiredJoin", "expiredLeave", "re-confirm!"] {
            let cell = AllocationCellPresentation(allocation: .init(index: 0, filter: "aa", status: status))
            XCTAssertEqual(cell.lifecycle, .attention)
        }
        let left = ShardAllocation(index: 0, filter: "aa", status: "expiredLeave", leaveConfirmFrame: 800)
        XCTAssertEqual(AllocationCellPresentation(allocation: left).lifecycleLabel, "Departed")
    }

    func testAbsentFreshClockDoesNotDisplayCalculatedDeadline() {
        let allocation = ShardAllocation(index: 0, filter: "aa", status: "joining", joinFrame: 100)
        XCTAssertNil(AllocationEpochPresentation(allocation: allocation, clock: nil))
    }

    func testRegistrationValueDoesNotIncludeUnmaskableContext() throws {
        let allocation = ShardAllocation(index: 0, filter: "aa", status: "active", registeredEpoch: 3)
        let timing = try XCTUnwrap(
            AllocationEpochPresentation(allocation: allocation, clock: .init(frame: 1000, epochLength: 720)))
        XCTAssertEqual(timing.label, "Registered through epoch")
        XCTAssertEqual(timing.value, "3")
    }
}
