import XCTest

@testable import QuilNodeApp
@testable import QuilNodeCore

final class EpochEstimateTests: XCTestCase {
    func testNonFinitePaceAndOverflowingDurationAreNotPresented() {
        for pace in [Double.nan, .infinity, -.infinity, 0, -1] {
            XCTAssertEqual(EpochEstimateFormatter.compact(framesRemaining: 720, framesPerMinute: pace), "ETA learning")
        }
        XCTAssertEqual(EpochEstimateFormatter.compact(framesRemaining: .max, framesPerMinute: 1), "ETA learning")
    }

    func testSubMinuteEstimateDoesNotSayZeroMinutes() {
        XCTAssertEqual(EpochEstimateFormatter.compact(framesRemaining: 1, framesPerMinute: 6), "<1m left")
    }

    func testQuietFramesSuppressAnOldRateAndOfflineSuppressesCountdown() {
        let now = Date(timeIntervalSince1970: 2000)
        var snapshot = NodeSnapshot(
            collectedAt: now, isRunning: true, frame: 1000,
            frameLastAdvancedAt: now.addingTimeInterval(-150), framesPerMinute: 6
        )
        XCTAssertEqual(EpochEstimateFormatter.compact(snapshot: snapshot, now: now), "Waiting for frames")
        snapshot.isRunning = false
        XCTAssertEqual(EpochEstimateFormatter.compact(snapshot: snapshot, now: now), "Node offline")
    }

    func testMenuEpochAndProgressDoNotMixDifferentSamples() {
        let presentation = MenuBarPresentation(
            snapshot: NodeSnapshot(lastReceivedFrame: 719, epoch: 0, nextEpochFrame: 720, frame: 730), phase: .ready
        )
        XCTAssertEqual(presentation.epoch, 1)
        XCTAssertEqual(presentation.framesUntilEpoch, 710)
        XCTAssertEqual(presentation.epochProgress, 10.0 / 720, accuracy: 0.0001)
    }
}
