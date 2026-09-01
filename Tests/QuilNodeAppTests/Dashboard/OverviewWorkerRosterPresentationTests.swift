import XCTest

@testable import QuilNodeApp
@testable import QuilNodeCore

final class OverviewWorkerRosterPresentationTests: XCTestCase {
    func testJoinsWorkerRuntimeToAllocationAndCoverageByFilter() throws {
        let snapshot = NodeSnapshot(
            shardAllocations: [
                ShardAllocation(
                    index: 0,
                    filter: "shard-a",
                    status: "active",
                    worker: "1",
                    activeProvers: 8,
                    ring: 1
                )
            ],
            localWorkerCount: 1,
            localWorkers: [
                LocalWorkerObservation(
                    coreID: 1,
                    filter: "shard-a",
                    availableStorage: "31 GB",
                    totalStorage: "40 GB"
                )
            ]
        )

        let worker = try XCTUnwrap(
            OverviewWorkerRosterPresentation.make(snapshot: snapshot).workers.first
        )

        XCTAssertEqual(worker.allocationState, .active)
        XCTAssertEqual(worker.allocationLabel, "Active")
        XCTAssertEqual(worker.coverage, .healthy)
        XCTAssertEqual(worker.activeProvers, 8)
        XCTAssertEqual(worker.ring, 1)
        XCTAssertEqual(worker.availableStorage, "31 GB")
    }

    func testFallsBackToExplicitWorkerIdentifierWhenFilterIsUnavailable() throws {
        let snapshot = NodeSnapshot(
            shardAllocations: [
                ShardAllocation(
                    index: 0,
                    filter: "shard-b",
                    status: "joining",
                    worker: "worker 4"
                )
            ],
            localWorkerCount: 1,
            localWorkers: [
                LocalWorkerObservation(
                    coreID: 4,
                    filter: "",
                    availableStorage: "",
                    totalStorage: ""
                )
            ]
        )

        let worker = try XCTUnwrap(
            OverviewWorkerRosterPresentation.make(snapshot: snapshot).workers.first
        )

        XCTAssertEqual(worker.filter, "shard-b")
        XCTAssertEqual(worker.allocationState, .joining)
        XCTAssertEqual(worker.allocationLabel, "Joining")
    }

    func testRetainsReportedCapacityWhileDetailedWorkerTelemetryLoads() {
        let presentation = OverviewWorkerRosterPresentation.make(
            snapshot: NodeSnapshot(localWorkerCount: 3, localWorkers: [])
        )

        XCTAssertEqual(presentation.workers.map(\.coreID), [1, 2, 3])
        XCTAssertEqual(
            presentation.workers.map(\.allocationState),
            [.awaitingAllocation, .awaitingAllocation, .awaitingAllocation]
        )
        XCTAssertEqual(presentation.reportedRunningCount, 3)
        XCTAssertFalse(presentation.isAwaitingEvidence)
    }

    func testRunningNodeWaitsForWorkerTelemetryInsteadOfClaimingNoWorkers() {
        let presentation = OverviewWorkerRosterPresentation.make(
            snapshot: NodeSnapshot(isRunning: true, localWorkerCount: nil, localWorkers: nil)
        )

        XCTAssertTrue(presentation.workers.isEmpty)
        XCTAssertTrue(presentation.isAwaitingEvidence)
    }

    func testStoppedNodeMayTruthfullyReportAnEmptyRoster() {
        let presentation = OverviewWorkerRosterPresentation.make(
            snapshot: NodeSnapshot(isRunning: false, localWorkerCount: nil, localWorkers: nil)
        )

        XCTAssertTrue(presentation.workers.isEmpty)
        XCTAssertFalse(presentation.isAwaitingEvidence)
    }

    func testOrdersWorkersDeterministicallyAndCapsTheOverviewProjection() {
        let presentation = OverviewWorkerRosterPresentation.make(
            snapshot: NodeSnapshot(
                localWorkerCount: 3,
                localWorkers: [
                    LocalWorkerObservation(coreID: 8, filter: "c", availableStorage: "", totalStorage: ""),
                    LocalWorkerObservation(coreID: 2, filter: "a", availableStorage: "", totalStorage: ""),
                    LocalWorkerObservation(coreID: 5, filter: "b", availableStorage: "", totalStorage: ""),
                ]
            )
        )

        XCTAssertEqual(presentation.workers.map(\.coreID), [2, 5, 8])
        XCTAssertEqual(presentation.visibleWorkers(limit: 2).map(\.coreID), [2, 5])
    }
}
