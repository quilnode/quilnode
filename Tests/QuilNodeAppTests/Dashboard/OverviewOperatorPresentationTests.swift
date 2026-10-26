import XCTest

@testable import QuilNodeApp
@testable import QuilNodeCore

final class OverviewOperatorPresentationTests: XCTestCase {
    func testRegistryTotalAloneCannotEstablishActiveOrJoiningCounts() {
        let snapshot = NodeSnapshot(
            isRunning: true, seniority: 42, seniorityUpdatedAt: Date(),
            seniorityEvidenceSource: .consensusRegistry, totalAllocations: 8
        )
        let presentation = OverviewOperatorPresentation.make(snapshot: snapshot, activitySamples: [])
        XCTAssertTrue(snapshot.hasSeniorityObservation)
        XCTAssertFalse(snapshot.hasAllocationObservation)
        XCTAssertNil(presentation.participation.activeAllocations)
        XCTAssertNil(presentation.participation.joiningAllocations)
    }

    func testFastRuntimeReadDoesNotInventZeroAllocationsBeforeProverRead() {
        var snapshot = NodeSnapshot(isRunning: true, frame: 10, localWorkerCount: 8)
        XCTAssertFalse(snapshot.hasAllocationObservation)
        let pending = OverviewOperatorPresentation.make(snapshot: snapshot, activitySamples: [])
        XCTAssertNil(pending.participation.activeAllocations)
        XCTAssertNil(pending.participation.joiningAllocations)
        XCTAssertEqual(pending.participation.runningWorkers, 8)

        snapshot.proverStatusUpdatedAt = Date()
        XCTAssertTrue(snapshot.hasAllocationObservation)
        let observed = OverviewOperatorPresentation.make(snapshot: snapshot, activitySamples: [])
        XCTAssertEqual(observed.participation.activeAllocations, 0)
        XCTAssertEqual(observed.participation.joiningAllocations, 0)
    }

    func testKeepsLandingPageEvidenceSeparateByOperatorQuestion() {
        let snapshot = NodeSnapshot(
            collectedAt: Date(timeIntervalSince1970: 2_000),
            isRunning: true,
            quilBalance: "12.50000000",
            lastRewardCreditFrame: 1_950,
            seniority: 42_000,
            shardAllocations: [
                ShardAllocation(
                    index: 0,
                    filter: "000100",
                    status: "active",
                    activeProvers: 8,
                    ring: 0
                )
            ],
            peers: 81,
            inboundConnectionsEstablished: 4,
            localWorkerCount: 3,
            archiveEndpointCount: 5,
            activeShards: 1,
            totalAllocations: 1
        )

        let presentation = OverviewOperatorPresentation.make(
            snapshot: snapshot,
            activitySamples: []
        )

        XCTAssertEqual(presentation.participation.activeAllocations, 1)
        XCTAssertEqual(presentation.participation.joiningAllocations, 0)
        XCTAssertEqual(presentation.participation.runningWorkers, 3)
        XCTAssertEqual(presentation.participation.coverage, .healthy)
        XCTAssertEqual(presentation.network.peers, 81)
        XCTAssertEqual(presentation.network.archiveSources, 5)
        XCTAssertTrue(presentation.network.inboundObserved)
        XCTAssertEqual(presentation.identity.seniority, 42_000)
        XCTAssertTrue(presentation.identity.seniorityIsObserved)
        XCTAssertEqual(presentation.rewards.balance, "12.50000000")
        XCTAssertEqual(presentation.rewards.lastCreditFrame, 1_950)
    }

    func testSelectsTheNewestMeaningfulActivityEvent() {
        let samples = [
            NodeActivitySample(
                timestamp: Date(timeIntervalSince1970: 1_000),
                frame: 100,
                peers: 10,
                pendingJoins: 0,
                activeShards: 1,
                totalAllocations: 1,
                isRunning: true
            ),
            NodeActivitySample(
                timestamp: Date(timeIntervalSince1970: 1_100),
                frame: 110,
                peers: 10,
                pendingJoins: 0,
                activeShards: 2,
                totalAllocations: 2,
                isRunning: true
            ),
            NodeActivitySample(
                timestamp: Date(timeIntervalSince1970: 1_200),
                frame: 120,
                peers: 10,
                pendingJoins: 0,
                activeShards: 2,
                totalAllocations: 2,
                isRunning: false
            ),
        ]

        let presentation = OverviewOperatorPresentation.make(
            snapshot: NodeSnapshot(),
            activitySamples: samples
        )

        XCTAssertEqual(presentation.latestActivity?.kind, .nodeStopped)
        XCTAssertEqual(presentation.latestActivity?.timestamp, Date(timeIntervalSince1970: 1_200))
    }
}
