import Foundation
import XCTest

@testable import QuilNodeApp
@testable import QuilNodeCore

final class OverviewStatusPresentationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testStartupAndOutdatedChecksDoNotClaimLiveNode() {
        let empty = NodeSnapshot()
        XCTAssertEqual(
            OverviewStatusPresentation(snapshot: empty, phase: .checkingProcess, now: now).title, "Checking this Mac")
        let outdated = NodeSnapshot(collectedAt: now.addingTimeInterval(-31), isRunning: true)
        let status = OverviewStatusPresentation(snapshot: outdated, phase: .ready, now: now)
        XCTAssertEqual(status.title, "Node readings are outdated")
        XCTAssertTrue(status.needsAttention)
    }

    func testActiveAssignmentDoesNotHideBlockedExecution() {
        let blocked = WorkerExecutionObservation(state: "blocked", observedAt: now, readAt: now)
        let snapshot = NodeSnapshot(
            collectedAt: now, isRunning: true,
            localWorkers: [
                .init(coreID: 1, filter: "aabb", availableStorage: "0 B", totalStorage: "0 B", execution: blocked)
            ], activeShards: 1)
        let status = OverviewStatusPresentation(snapshot: snapshot, phase: .ready, now: now)
        XCTAssertEqual(status.workersNeedingReview, 1)
        XCTAssertEqual(status.title, "Node running · review workers")
        XCTAssertTrue(status.needsAttention)
    }

    func testAbsentRewardCreditDoesNotTurnRunningNodeIntoFailure() {
        let snapshot = NodeSnapshot(collectedAt: now, isRunning: true, activeShards: 8)
        let status = OverviewStatusPresentation(snapshot: snapshot, phase: .ready, now: now)
        XCTAssertEqual(status.title, "Node running")
        XCTAssertFalse(status.needsAttention)
    }

    func testResourcesDistinguishProcessTimeAndBinaryMemory() {
        XCTAssertEqual(RuntimeResourceFormatter.uptime("1-04:12:35"), "1d 4h 12m")
        XCTAssertEqual(RuntimeResourceFormatter.uptime("04:12:35"), "4h 12m")
        XCTAssertEqual(RuntimeResourceFormatter.uptime("00:03"), "0m 3s")
        XCTAssertEqual(RuntimeResourceFormatter.uptime(nil), "—")
        XCTAssertEqual(RuntimeResourceFormatter.uptime("not a time"), "—")
        XCTAssertEqual(RuntimeResourceFormatter.uptime("1:99:33"), "—")
        XCTAssertTrue(RuntimeResourceFormatter.memory(1024).contains("GiB"))
        XCTAssertEqual(RuntimeResourceFormatter.memory(.nan), "—")
    }
}
