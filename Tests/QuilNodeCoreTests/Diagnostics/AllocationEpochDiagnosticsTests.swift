import XCTest

@testable import QuilNodeCore

final class AllocationEpochDiagnosticsTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 2000)

    func testConfirmedJoinIsExpectedWaitingNotRepair() throws {
        let check = try result(ShardAllocation(index: 0, filter: "aa", status: "joining", confirmFrame: 800))
        XCTAssertEqual(check.state, .waiting)
        XCTAssertNil(check.repair)
    }

    func testMissedRenewalOnlyOffersReadOnlyEvidenceRefresh() throws {
        let check = try result(ShardAllocation(index: 0, filter: "aa", status: "re-confirm!", registeredEpoch: 0))
        XCTAssertEqual(check.state, .advisory)
        XCTAssertEqual(check.repair, .refreshEvidence)
        XCTAssertTrue(check.evidence.contains("automatically"))
    }

    func testStaleMissedRenewalIsNotANewAlarm() throws {
        let check = try result(
            ShardAllocation(index: 0, filter: "aa", status: "re-confirm!"), age: 181
        )
        XCTAssertEqual(check.state, .checking)
        XCTAssertEqual(check.repair, .refreshEvidence)
    }

    func testNextEpochRegistrationPassesWithoutClaimingRewards() throws {
        let check = try result(ShardAllocation(index: 0, filter: "aa", status: "active", registeredEpoch: 2))
        XCTAssertEqual(check.state, .passed)
        XCTAssertTrue(check.evidence.contains("separate evidence"))
    }

    func testActiveCurrentEpochDoesNotBecomeWaitingBecauseRoutineRenewalIsDue() throws {
        let check = try result(ShardAllocation(index: 0, filter: "aa", status: "active", registeredEpoch: 1))
        XCTAssertEqual(check.state, .passed)
        XCTAssertNil(check.repair)
    }

    func testConfirmedDepartureDoesNotTriggerMissedWindowAlarm() throws {
        let check = try result(
            ShardAllocation(index: 0, filter: "aa", status: "expiredLeave", leaveConfirmFrame: 100)
        )
        XCTAssertNotEqual(check.state, .advisory)
        XCTAssertNotEqual(check.state, .failed)
    }

    private func result(_ allocation: ShardAllocation, age: TimeInterval = 0) throws -> NodeDiagnosticCheck {
        let snapshot = NodeSnapshot(
            isRunning: true,
            proverStatusUpdatedAt: now.addingTimeInterval(-age),
            shardAllocations: [allocation], frame: 1000
        )
        let context = NodeDiagnosticContext(
            snapshot: snapshot, initialRefreshComplete: true, serviceAvailable: true,
            networkAssessment: .init(state: .inspecting, title: "Inspecting", detail: "Checking"),
            networkInspection: .empty, firewall: nil, qclientReady: true, qclientCompatible: true, now: now
        )
        return try XCTUnwrap(NodeDiagnosticEvaluator.allocationEpochCheck(context))
    }
}
