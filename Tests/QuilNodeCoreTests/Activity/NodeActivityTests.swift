import Foundation
import XCTest

@testable import QuilNodeCore
@testable import QuilNodeShared

final class NodeActivityTests: XCTestCase {
    func testActivitySummaryAndEventDerivation() {
        let activityStart = Date(timeIntervalSince1970: 2_000_000_000)
        let activitySamples = [
            NodeActivitySample(
                timestamp: activityStart,
                frame: 100,
                peers: 10,
                pendingJoins: 0,
                activeShards: 0,
                totalAllocations: 0,
                isRunning: true,
                seniority: 1_000,
                inboundConnections: 0,
                routerDrops: 0,
                version: "2.1.0.25"
            ),
            NodeActivitySample(
                timestamp: activityStart.addingTimeInterval(60),
                frame: 106,
                peers: 12,
                pendingJoins: 2,
                activeShards: 0,
                totalAllocations: 2,
                isRunning: true,
                seniority: 1_000,
                inboundConnections: 1,
                routerDrops: 0,
                version: "2.1.0.25"
            ),
            NodeActivitySample(
                timestamp: activityStart.addingTimeInterval(120),
                frame: 112,
                peers: 3,
                pendingJoins: 0,
                activeShards: 2,
                totalAllocations: 2,
                isRunning: true,
                seniority: 1_010,
                inboundConnections: 1,
                lastRewardCreditFrame: 110,
                version: "2.1.0.25"
            ),
        ]
        let activitySummary = NodeActivityAnalyzer.summarize(activitySamples)
        expect(activitySummary.frameDelta == 12, "activity frame delta")
        expect(activitySummary.averageFramesPerMinute == 6, "activity frame pace")
        expect(activitySummary.peerMinimum == 3 && activitySummary.peerMaximum == 12, "activity peer band")
        let activityEvents = NodeActivityAnalyzer.events(from: activitySamples)
        expect(activityEvents.contains { $0.kind == .inboundObserved }, "activity inbound event")
        expect(
            activityEvents.filter { $0.kind == .inboundObserved }.count == 1,
            "activity records first inbound proof without flooding the journal"
        )
        expect(activityEvents.contains { $0.kind == .activeShardChanged }, "activity shard lifecycle event")
        expect(activityEvents.contains { $0.kind == .seniorityChanged }, "activity seniority event")
        expect(activityEvents.contains { $0.kind == .rewardCredited }, "activity reward event")

    }

    func testRecoveryEvidenceFlappingDoesNotFloodJournal() {
        let start = Date(timeIntervalSince1970: 2_000_000_000)
        let states: [ChainProgressState] = [
            .advancing, .archiveRecovery, .advancing, .archiveRecovery, .advancing, .archiveRecovery,
        ]
        let samples = states.enumerated().map { index, state in
            NodeActivitySample(
                timestamp: start.addingTimeInterval(Double(index * 30)),
                frame: 100,
                peers: 20,
                pendingJoins: 0,
                activeShards: 0,
                totalAllocations: 0,
                isRunning: true,
                chainProgressState: state
            )
        }

        let events = NodeActivityAnalyzer.events(from: samples)
        XCTAssertEqual(events.filter { $0.kind == .archiveRecoveryStarted }.count, 1)
        XCTAssertEqual(events.filter { $0.kind == .archiveRecoveryEnded }.count, 1)
    }
}
