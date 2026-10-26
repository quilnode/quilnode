import Foundation
import XCTest

@testable import QuilNodeApp
@testable import QuilNodeCore

final class ActivityPresentationTests: XCTestCase {
    func testMissingFrameBaselinesNeverBecomeProgressSpikes() {
        let start = Date(timeIntervalSince1970: 2_000_000_000)
        let samples = [
            sample(at: start, frame: 0, peers: 0),
            sample(at: start.addingTimeInterval(60), frame: 935_000, peers: 80),
            sample(at: start.addingTimeInterval(90), frame: 0, peers: 0),
            sample(at: start.addingTimeInterval(120), frame: 935_006, peers: 81),
        ]
        let summary = NodeActivityAnalyzer.summarize(samples)
        XCTAssertEqual(summary.frameDelta, 6)
        XCTAssertEqual(summary.averageFramesPerMinute, 6)
        XCTAssertTrue(
            ActivityPresentation.intervalPoints(from: samples).isEmpty,
            "Missing readings split the plotted observation runs")
    }

    func testIntervalPointsAndStableNarrativeUseLocalEvidence() {
        let start = Date(timeIntervalSince1970: 2_000_000_000)
        let samples = [
            sample(at: start, frame: 100, peers: 100),
            sample(at: start.addingTimeInterval(60), frame: 106, peers: 102),
            sample(at: start.addingTimeInterval(120), frame: 112, peers: 101),
        ]

        let points = ActivityPresentation.intervalPoints(from: samples)
        XCTAssertEqual(points.count, 2)
        XCTAssertEqual(points.first?.framesPerMinute, 6)

        let narrative = ActivityPresentation.narrative(
            summary: NodeActivityAnalyzer.summarize(samples),
            assessment: ChainProgressAssessment(state: .advancing),
            sampleCount: samples.count
        )
        XCTAssertEqual(narrative.title, "Frames advanced steadily; peer mesh remained stable.")
    }

    func testArchiveRecoveryNarrativeDoesNotRecommendRestart() {
        let narrative = ActivityPresentation.narrative(
            summary: NodeActivitySummary(frameDelta: 0, continuity: 1),
            assessment: ChainProgressAssessment(state: .archiveRecovery),
            sampleCount: 20
        )

        XCTAssertTrue(narrative.title.contains("archives converge"))
        XCTAssertTrue(narrative.subtitle.contains("restarting is not recommended"))
    }

    func testEventPresentationClassifiesSourcePrivacyAndAction() {
        let event = NodeActivityEvent(
            id: "router",
            timestamp: Date(),
            category: .network,
            kind: .routerDropsIncreased,
            title: "Router filtered messages",
            detail: "Filtered locally",
            sensitiveValue: "+44 messages"
        )

        XCTAssertEqual(event.journalSection, .router)
        XCTAssertEqual(event.evidenceSource, "Router statistics")
        XCTAssertEqual(event.actionState, .review)
        XCTAssertEqual(event.privacyField, .networkActivity)
    }

    func testChartDoesNotBridgeAnUnobservedHour() {
        let start = Date(timeIntervalSince1970: 2_000_000_000)
        let samples = [
            sample(at: start, frame: 100, peers: 80),
            sample(at: start.addingTimeInterval(30), frame: 103, peers: 81),
            sample(at: start.addingTimeInterval(3600), frame: 200, peers: 82),
            sample(at: start.addingTimeInterval(3630), frame: 203, peers: 83),
        ]
        let points = ActivityPresentation.intervalPoints(from: samples)
        XCTAssertEqual(points.map(\.framesPerMinute), [6, 6])
        XCTAssertEqual(Set(points.map(\.segment)).count, 2)
    }

    func testMissingPeerReadIsNotAZeroOrConnectivityEvent() {
        let start = Date(timeIntervalSince1970: 2_000_000_000)
        var missing = sample(at: start, frame: 100, peers: 0)
        missing.peersObserved = false
        let known = sample(at: start.addingTimeInterval(30), frame: 103, peers: 80)
        let summary = NodeActivityAnalyzer.summarize([missing, known])
        XCTAssertEqual(summary.peerMinimum, 80)
        XCTAssertEqual(summary.peerDelta, 0)
        XCTAssertFalse(NodeActivityAnalyzer.events(from: [missing, known]).contains { $0.kind == .peerMeshChanged })
        missing.peersObserved = true
        XCTAssertEqual(NodeActivityAnalyzer.summarize([missing, known]).peerMinimum, 0)
        XCTAssertTrue(NodeActivityAnalyzer.events(from: [missing, known]).contains { $0.kind == .peerMeshChanged })
    }

    private func sample(at timestamp: Date, frame: UInt64, peers: Int) -> NodeActivitySample {
        NodeActivitySample(
            timestamp: timestamp,
            frame: frame,
            peers: peers,
            pendingJoins: 0,
            activeShards: 0,
            totalAllocations: 0,
            isRunning: true
        )
    }
}
