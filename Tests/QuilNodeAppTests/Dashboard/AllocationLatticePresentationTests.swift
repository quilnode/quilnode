import XCTest

@testable import QuilNodeApp
@testable import QuilNodeCore

final class AllocationLatticePresentationTests: XCTestCase {
    func testWorkerRuntimeAndAllocationLifecycleRemainIndependent() {
        let snapshot = NodeSnapshot(
            localWorkerCount: 9,
            pendingJoins: 5,
            activeShards: 4,
            totalAllocations: 9
        )

        let presentation = AllocationLatticePresentation.make(snapshot: snapshot)

        XCTAssertEqual(presentation.runningWorkers, 9)
        XCTAssertEqual(presentation.activeAllocations, 4)
        XCTAssertEqual(presentation.joiningAllocations, 5)
        XCTAssertEqual(presentation.totalAllocations, 9)
        XCTAssertTrue(presentation.hasMixedLifecycle)
    }

    func testAllocatedWorkerCountIsNotPresentedAsRunningWorkerEvidence() {
        let snapshot = NodeSnapshot(
            allocatedWorkers: 9,
            localWorkerCount: nil,
            pendingJoins: 5,
            activeShards: 4,
            totalAllocations: 9
        )

        let presentation = AllocationLatticePresentation.make(snapshot: snapshot)

        XCTAssertNil(presentation.runningWorkers)
    }

    func testCoverageSummaryUsesTheMostUrgentAssignedShardState() {
        let snapshot = NodeSnapshot(
            shardAllocations: [
                ShardAllocation(index: 0, filter: "a", status: "active", activeProvers: 62),
                ShardAllocation(index: 1, filter: "b", status: "joining", activeProvers: 3),
            ]
        )

        XCTAssertEqual(
            AllocationLatticePresentation.make(snapshot: snapshot).coverageState,
            .atRisk
        )
    }
}
