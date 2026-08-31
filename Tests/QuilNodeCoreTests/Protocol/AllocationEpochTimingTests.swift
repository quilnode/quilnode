import XCTest

@testable import QuilNodeCore

final class AllocationEpochTimingTests: XCTestCase {
    func testConfirmWindowAndDeferredActivationOnBothNetworks() {
        for length: UInt64 in [60, 720] {
            var allocation = ShardAllocation(index: 0, filter: "aabb", status: "joining", joinFrame: 10)
            XCTAssertEqual(timing(allocation, at: length - 1, length: length), .confirmationOpens(frame: length))
            XCTAssertEqual(timing(allocation, at: length, length: length), .confirmationCloses(frame: length * 2))
            allocation.confirmFrame = length + 1
            XCTAssertEqual(timing(allocation, at: length + 2, length: length), .activation(frame: length * 2))
            XCTAssertEqual(timing(allocation, at: length * 2, length: length), .awaitingRegistry)
            // A clock crossing must never silently turn Joining into Active.
            XCTAssertEqual(AllocationStatus(allocation.status), .joining)
        }
    }

    func testStaleUnconfirmedReadDoesNotInventAMissedWindow() {
        let allocation = ShardAllocation(index: 0, filter: "aa", status: "joining", joinFrame: 1)
        XCTAssertEqual(timing(allocation, at: 1440), .awaitingRegistry)
    }

    func testRenewalAheadDueAndMissedAreDifferent() {
        var allocation = ShardAllocation(index: 0, filter: "aa", status: "active", registeredEpoch: 3)
        XCTAssertEqual(timing(allocation, at: 1440), .registeredThrough(epoch: 3))
        allocation.registeredEpoch = 2
        XCTAssertEqual(timing(allocation, at: 1440), .renewalDue(frame: 2160))
        allocation.registeredEpoch = 1
        XCTAssertEqual(timing(allocation, at: 1440), .awaitingRegistry)
        allocation.status = "re-confirm!"
        XCTAssertEqual(timing(allocation, at: 1440), .renewalMissed)
    }

    func testGlobalAndLegacyAllocationsDoNotAcquireInventedObligations() {
        let global = ShardAllocation(index: 0, filter: "", status: "active", registeredEpoch: 0)
        XCTAssertEqual(timing(global, at: 2000), .unavailable)
        let legacy = ShardAllocation(index: 1, filter: "aa", status: "joining", joinFrame: 0)
        XCTAssertEqual(timing(legacy, at: 2000), .unavailable)
        let missing = ShardAllocation(index: 2, filter: "bb", status: "active")
        XCTAssertEqual(timing(missing, at: 2000), .unavailable)
    }

    func testFutureAndOverflowingFramesAreNotInterpretedAsDeadlines() {
        var allocation = ShardAllocation(index: 0, filter: "aa", status: "joining", joinFrame: 2000)
        XCTAssertEqual(timing(allocation, at: 1000), .unavailable)
        allocation.joinFrame = .max
        XCTAssertEqual(timing(allocation, at: .max), .unavailable)
        allocation.joinFrame = 1
        allocation.confirmFrame = 2000
        XCTAssertEqual(timing(allocation, at: 1000), .unavailable)
    }

    func testConfirmedLeaveIsNotReportedAsFailure() {
        var allocation = ShardAllocation(
            index: 0, filter: "aa", status: "leaving", leaveFrame: 100, leaveConfirmFrame: 800
        )
        XCTAssertEqual(timing(allocation, at: 900), .departure(frame: 1440))
        XCTAssertEqual(timing(allocation, at: 1440), .awaitingRegistry)
        allocation.status = "expiredLeave"
        XCTAssertEqual(timing(allocation, at: 1500), .unavailable)
        allocation.leaveConfirmFrame = nil
        XCTAssertEqual(timing(allocation, at: 1500), .windowMissed)
    }

    func testCLIAndPersistedStatusSpellings() {
        for label in ["expiredJoin", "expired_joining", "ExpiredJoining"] {
            XCTAssertEqual(AllocationStatus(label), .expiredJoin)
        }
        for label in ["re-confirm!", "expired_epoch", "ExpiredEpoch"] {
            XCTAssertEqual(AllocationStatus(label), .renewalMissed)
        }
        XCTAssertEqual(AllocationStatus("historic"), .historic)
        XCTAssertEqual(AllocationStatus("brand-new-state"), .unknown)
    }

    private func timing(_ allocation: ShardAllocation, at frame: UInt64, length: UInt64 = 720) -> AllocationEpochTiming
    {
        .evaluate(allocation, clock: NodeEpochClock(frame: frame, epochLength: length))
    }
}
