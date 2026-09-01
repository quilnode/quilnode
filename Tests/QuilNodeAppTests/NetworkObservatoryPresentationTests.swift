import XCTest

@testable import QuilNodeApp
@testable import QuilNodeCore

final class NetworkObservatoryPresentationTests: XCTestCase {
    func testBuildsTruthfulLocalScopesFromRetainedShardRows() {
        let observedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let shards = [
            shard("healthy", provers: 7),
            shard("local", provers: 5, allocated: true),
            shard("risk", provers: 2),
            shard("empty", provers: 0),
        ]
        let snapshot = NodeSnapshot(
            isRunning: true,
            epoch: 12,
            shardAllocations: [ShardAllocation(index: 0, filter: "local", status: "active", worker: "1")],
            networkShards: shards,
            networkShardSummary: NetworkShardSummary(shards: shards, frame: 9_999, observedAt: observedAt),
            frame: 9_998,
            peers: 42,
            archiveEndpointCount: 5
        )

        let presentation = NetworkObservatoryPresentation.make(snapshot: snapshot, now: observedAt)

        XCTAssertEqual(presentation.evidenceState, .current)
        XCTAssertEqual(presentation.frame, 9_999)
        XCTAssertEqual(presentation.localAllocationCount, 1)
        XCTAssertEqual(presentation.visibleShards(filter: .local, query: "").map(\.id), ["local"])
        XCTAssertEqual(
            Set(presentation.visibleShards(filter: .attention, query: "").map(\.id)),
            Set(["local", "risk", "empty"])
        )
        XCTAssertEqual(presentation.visibleShards(filter: .all, query: "ring 0").count, 4)
        XCTAssertEqual(presentation.preferredSelection, "local")
    }

    func testSeparatesLoadingUnavailableAndStaleEvidence() {
        let now = Date(timeIntervalSince1970: 1_800_000_500)
        XCTAssertEqual(
            NetworkObservatoryPresentation.make(
                snapshot: NodeSnapshot(isRunning: true, networkShards: nil),
                now: now
            ).evidenceState,
            .loading
        )
        XCTAssertEqual(
            NetworkObservatoryPresentation.make(
                snapshot: NodeSnapshot(isRunning: false, networkShards: nil),
                now: now
            ).evidenceState,
            .unavailable
        )

        let shards = [shard("stale", provers: 6)]
        let old = now.addingTimeInterval(-181)
        XCTAssertEqual(
            NetworkObservatoryPresentation.make(
                snapshot: NodeSnapshot(
                    isRunning: true,
                    networkShards: shards,
                    networkShardSummary: NetworkShardSummary(shards: shards, observedAt: old)
                ),
                now: now
            ).evidenceState,
            .stale
        )
    }

    private func shard(_ filter: String, provers: Int, allocated: Bool = false) -> NetworkShardObservation {
        NetworkShardObservation(
            filter: filter,
            shardSize: "4 GB",
            dataShards: 1,
            activeProvers: provers,
            ring: 0,
            estimatedRewardPerFrame: "0.001",
            isAllocated: allocated,
            worker: allocated ? "1" : nil
        )
    }
}
