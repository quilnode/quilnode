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
        XCTAssertEqual(presentation.epoch, 13)
        XCTAssertEqual(presentation.epochProgress, 639.0 / 720.0, accuracy: 0.0001)
        XCTAssertEqual(presentation.localAllocationCount, 1)
        XCTAssertEqual(presentation.proverMemberships, 14)
        XCTAssertEqual(presentation.ringDistribution.compactLabel, "R0 4 · R1 0 · R2 0 · R3+ 0")
        XCTAssertEqual(presentation.visibleShards(filter: .local, query: "").map(\.id), ["local"])
        XCTAssertEqual(
            Set(presentation.visibleShards(filter: .attention, query: "").map(\.id)),
            Set(["local", "risk", "empty"])
        )
        XCTAssertEqual(presentation.visibleShards(filter: .all, query: "ring 0").count, 4)
        XCTAssertEqual(presentation.visibleShards(filter: .all, query: "worker 1").map(\.id), ["local"])
        XCTAssertEqual(presentation.preferredSelection, "local")
    }

    func testKeepsWorkerAllocationCoverageAndRewardEvidenceIndependent() {
        let observedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let shards = [
            NetworkShardObservation(
                filter: "local-a",
                shardSize: "4 GB",
                dataShards: 1,
                activeProvers: 7,
                ring: 0,
                estimatedRewardPerFrame: "0.001",
                isAllocated: true,
                worker: "1"
            ),
            NetworkShardObservation(
                filter: "local-b",
                shardSize: "4 GB",
                dataShards: 1,
                activeProvers: 2,
                ring: 1,
                estimatedRewardPerFrame: "0.002",
                isAllocated: true,
                worker: "2"
            ),
        ]
        let snapshot = NodeSnapshot(
            collectedAt: observedAt,
            isRunning: true,
            peerID: "private-local-peer",
            quilBalance: "12.50000000",
            lastRewardCreditFrame: 9_900,
            seniority: 1_234,
            allocatedWorkers: 7,
            networkShards: shards,
            networkShardSummary: NetworkShardSummary(shards: shards, observedAt: observedAt),
            localWorkerCount: 9,
            localWorkers: [
                LocalWorkerObservation(
                    coreID: 1,
                    filter: "local-a",
                    availableStorage: "12.4 GB",
                    totalStorage: "40.0 GB"
                )
            ],
            pendingJoins: 5,
            activeShards: 4,
            totalAllocations: 9
        )

        let node = NetworkObservatoryPresentation.make(snapshot: snapshot, now: observedAt).localNode

        XCTAssertEqual(node.runningWorkers, 9)
        XCTAssertEqual(node.allocatedWorkers, 7)
        XCTAssertEqual(node.workers.first?.availableStorage, "12.4 GB")
        XCTAssertEqual(node.activeAllocations, 4)
        XCTAssertEqual(node.joiningAllocations, 5)
        XCTAssertEqual(node.totalAllocations, 9)
        XCTAssertEqual(node.allocationCoverage.healthy, 1)
        XCTAssertEqual(node.allocationCoverage.atRisk, 1)
        XCTAssertEqual(node.estimatedRewardPerFrame, "0.003")
        XCTAssertEqual(node.estimatedRewardPerTargetDay, "25.92")
        XCTAssertEqual(node.lastRewardCreditFrame, 9_900)
        XCTAssertTrue(node.matches("private-local-peer"))
        XCTAssertFalse(node.matches("private-local-peer", includesPrivateIdentifiers: false))
    }

    func testPrivacySearchDoesNotUseLocalWorkerAssignments() {
        let shards = [shard("local", provers: 7, allocated: true)]
        let presentation = NetworkObservatoryPresentation.make(
            snapshot: NodeSnapshot(isRunning: true, networkShards: shards)
        )

        XCTAssertEqual(
            presentation.visibleShards(filter: .all, query: "worker 1").map(\.id),
            ["local"]
        )
        XCTAssertTrue(
            presentation.visibleShards(
                filter: .all,
                query: "worker 1",
                includesLocalAssignments: false
            ).isEmpty
        )
    }

    func testFeaturedShardsDoNotUsePrivateAllocationEvidenceInPrivacyMode() {
        let observedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let shards = [
            shard("healthy-local", provers: 12, allocated: true),
            shard("at-risk", provers: 2),
            shard("below-target", provers: 5),
            shard("healthy-public", provers: 9),
        ]
        let presentation = NetworkObservatoryPresentation.make(
            snapshot: NodeSnapshot(
                isRunning: true,
                shardAllocations: [
                    ShardAllocation(index: 0, filter: "healthy-local", status: "active", worker: "1")
                ],
                networkShards: shards,
                networkShardSummary: NetworkShardSummary(shards: shards, observedAt: observedAt)
            ),
            now: observedAt
        )

        XCTAssertEqual(
            presentation.featuredShardIDs(revealsLocalTopology: true, limit: 1),
            Set(["healthy-local"])
        )
        XCTAssertEqual(
            presentation.featuredShardIDs(revealsLocalTopology: false, limit: 1),
            Set(["at-risk"])
        )
    }

    func testSemanticLayoutKeepsContextShardsSmallerThanFeaturedShards() {
        let featured = NetworkShardPresentation(observation: shard("featured", provers: 8))
        let context = NetworkShardPresentation(observation: shard("context", provers: 8))
        let layouts = ShardConstellationLayout.layouts(
            for: [featured, context],
            featuredIDs: Set([featured.id]),
            selectedID: featured.id,
            size: CGSize(width: 900, height: 500),
            zoom: 1
        )

        XCTAssertEqual(layouts[featured.id]?.isFeatured, true)
        XCTAssertEqual(layouts[context.id]?.isFeatured, false)
        XCTAssertGreaterThan(layouts[featured.id]?.radius ?? 0, layouts[context.id]?.radius ?? 0)
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
