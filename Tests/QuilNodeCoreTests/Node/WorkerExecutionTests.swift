import Foundation
import XCTest

@testable import QuilNodeCore

final class WorkerExecutionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testCurrentClientSeparatesAssignmentExecutionRecoveryAndSeal() throws {
        // Shape from quil-client 8e80d12faa68; values are synthetic.
        let output = """
            Seniority: 42
            Running Workers: 3 of 2 configured | draining 1
            Shard Allocations:
            [0] Filter: aabb Status: Active Worker: 1
            Next Action: epoch in 20 frames  Default Action: re-confirm
            Workers (3):
            Core 1: Filter: aabb  Storage: 0 B / 0 B
              Local execution: blocked (checkpoint mismatch); height 12; last advance 90s ago; observation 2s ago; Recovery: replaying_frames (>60s), attempt 6 (5 failed in a row), 4 leaves installed in it
            Core 2: Filter: ccdd  Storage: 1 GB / 2 GB  Draining: above the configured count; stops once its seat departs
              Local execution: handoff; height 50; last advance 4s ago; observation 1s ago; Seal: generation 3 at frame 50 (view 8), finalized <60s, recorded by GLOBAL <60s
            Core 3: Filter: eeff  Storage: 0 B / 0 B
              Local execution: unknown (node has no worker observations)
            """
        let status = try XCTUnwrap(ProverStatusParser.parse(output, readAt: now))
        XCTAssertEqual(status.runningWorkers, 3)
        XCTAssertTrue(status.allocations[0].action?.contains("re-confirm") == true)
        XCTAssertEqual(status.allocations[0].status, "Active")
        let blocked = try XCTUnwrap(status.workers[0].execution)
        XCTAssertEqual(blocked.state, "blocked")
        XCTAssertEqual(blocked.blocker, "checkpoint mismatch")
        XCTAssertEqual(blocked.frame, 12)
        XCTAssertEqual(blocked.observedAt, now.addingTimeInterval(-2))
        XCTAssertEqual(blocked.lastAdvanceAt, now.addingTimeInterval(-90))
        XCTAssertEqual(blocked.recoveryPhase, "replaying_frames")
        XCTAssertEqual(blocked.recoveryFailures, 5)
        XCTAssertNil(blocked.sealRecorded)
        XCTAssertEqual(status.workers[1].totalStorage, "2 GB")
        XCTAssertEqual(status.workers[1].isDraining, true)
        XCTAssertEqual(status.workers[1].execution?.sealRecorded, true)
        XCTAssertNil(status.workers[2].execution?.observedAt)
        XCTAssertNil(status.workers[2].execution?.frame)
    }

    func testOldWorkerCacheDecodesWithoutInventingExecution() throws {
        let old = Data(#"{"coreID":1,"filter":"aabb","availableStorage":"0 B","totalStorage":"0 B"}"#.utf8)
        let worker = try JSONDecoder().decode(LocalWorkerObservation.self, from: old)
        XCTAssertNil(worker.execution)
        XCTAssertNil(worker.isDraining)
    }

    func testUnknownAndOversizedExecutionCannotClaimHealthyEvidence() throws {
        let unknown = try XCTUnwrap(
            WorkerExecutionParser.parse(
                "Local execution: newstate; height unknown; last advance unobserved; observation - ago", readAt: now))
        XCTAssertEqual(unknown.state, "unknown")
        XCTAssertNil(unknown.frame)
        XCTAssertFalse(unknown.isFresh(at: now))
        XCTAssertNil(
            WorkerExecutionParser.parse("Local execution: " + String(repeating: "a", count: 17_000), readAt: now))
        let stale = try XCTUnwrap(
            WorkerExecutionParser.parse(
                "Local execution: running; height 0; last advance unobserved; observation 31s ago", readAt: now))
        XCTAssertEqual(stale.frame, 0)
        XCTAssertFalse(stale.isFresh(at: now))
    }

    func testExecutionExpiresIndependentlyOfFreshSnapshot() {
        let execution = WorkerExecutionObservation(state: "running", observedAt: now, readAt: now)
        XCTAssertTrue(execution.isFresh(at: now.addingTimeInterval(60)))
        XCTAssertFalse(execution.isFresh(at: now.addingTimeInterval(121)))
        XCTAssertFalse(execution.isFresh(at: now.addingTimeInterval(-1)))
    }
}
