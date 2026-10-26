import XCTest

@testable import QuilNodeApp
@testable import QuilNodeCore

final class NetworkRewardEvidenceTests: XCTestCase {
    func testDailyEstimateDoesNotFabricatePerFramePrecisionOrUnknownRings() {
        let shard = NetworkShardObservation(
            filter: "aabb", shardSize: "1 GB", dataShards: 1, activeProvers: 6,
            ring: nil, estimatedRewardPerFrame: nil, isAllocated: true, estimatedRewardPerDay: "33"
        )
        let presentation = NetworkLocalNodePresentation.make(
            snapshot: NodeSnapshot(), shards: [NetworkShardPresentation(observation: shard)]
        )
        XCTAssertNil(presentation.estimatedRewardPerFrame)
        XCTAssertEqual(presentation.estimatedRewardPerTargetDay, "33")
        XCTAssertEqual(presentation.localRings.ring0, 0)
        XCTAssertEqual(presentation.localRings.unknown, 1)
    }

    func testStaleOrIncompleteRewardDataDoesNotProduceATotal() {
        var shard = NetworkShardObservation(
            filter: "aabb", shardSize: "1 GB", dataShards: 1, activeProvers: 6,
            ring: 1, estimatedRewardPerFrame: "0.001", isAllocated: true
        )
        let stale = NetworkLocalNodePresentation.make(
            snapshot: NodeSnapshot(), shards: [NetworkShardPresentation(observation: shard)], estimatesAreCurrent: false
        )
        XCTAssertNil(stale.estimatedRewardPerFrame)
        XCTAssertNil(stale.estimatedRewardPerTargetDay)
        let known = shard
        shard.filter = "ccdd"
        shard.estimatedRewardPerFrame = nil
        let incomplete = NetworkLocalNodePresentation.make(
            snapshot: NodeSnapshot(), shards: [known, shard].map(NetworkShardPresentation.init)
        )
        XCTAssertNil(incomplete.estimatedRewardPerTargetDay)
    }
}
