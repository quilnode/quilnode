import Foundation
import XCTest

@testable import QuilNodeCore

final class TelemetryRefreshTests: XCTestCase {
    func testMissingStatusSampleDoesNotEraseKnownCounts() {
        let warning = "2026-10-26T09:54:17Z\twarn\tworker.rs:244\tworker thread blocked\t{\"coreId\":2}"
        let status = NodeStatusParser.latestStatus(in: warning) ?? [:]
        XCTAssertEqual(NodeStatusParser.int(status, "active_shards", fallback: 8), 8)
        XCTAssertEqual(NodeStatusParser.int(status, "peers", fallback: 64), 64)
        XCTAssertEqual(NodeStatusParser.uint64(status, "frame", fallback: 935_572), 935_572)
        XCTAssertEqual(NodeStatusParser.int(["peers": 0], "peers", fallback: 64), 0)
        XCTAssertEqual(NodeStatusParser.int(["peers": "unknown"], "peers", fallback: 64), 64)
    }

    func testConcurrentRPCAllocationResultSurvivesSlowCollection() {
        var collection = NodeSnapshot.empty
        collection.processID = 123
        collection.proverStatusUpdatedAt = Date(timeIntervalSince1970: 10)
        var rpc = collection
        rpc.proverStatusUpdatedAt = Date(timeIntervalSince1970: 20)
        rpc.activeShards = 8
        rpc.totalAllocations = 8
        rpc.frame = 935_572
        collection.preferNewerProverObservation(from: rpc)
        XCTAssertEqual(collection.activeShards, 8)
        XCTAssertEqual(collection.totalAllocations, 8)
        XCTAssertEqual(collection.frame, 935_572)

        // A newer complete empty allocation result is also real evidence.
        rpc.proverStatusUpdatedAt = Date(timeIntervalSince1970: 30)
        rpc.activeShards = 0
        rpc.totalAllocations = 0
        collection.preferNewerProverObservation(from: rpc)
        XCTAssertEqual(collection.activeShards, 0)
        XCTAssertEqual(collection.totalAllocations, 0)

        rpc.processID = 456
        rpc.activeShards = 9
        collection.preferNewerProverObservation(from: rpc)
        XCTAssertEqual(collection.activeShards, 0)
    }
}
