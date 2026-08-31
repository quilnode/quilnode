import XCTest

@testable import QuilNodeCore

final class NodeEpochClockTests: XCTestCase {
    func testHalfOpenEpochBoundaries() {
        for length: UInt64 in [60, 720] {
            let before = NodeEpochClock(frame: length - 1, epochLength: length)
            XCTAssertEqual(before.epoch, 0)
            XCTAssertEqual(before.framesRemaining, 1)
            XCTAssertEqual(before.nextBoundary, length)
            let boundary = NodeEpochClock(frame: length, epochLength: length)
            XCTAssertEqual(boundary.epoch, 1)
            XCTAssertEqual(boundary.progress, 0)
            XCTAssertEqual(boundary.framesRemaining, length)
            XCTAssertEqual(boundary.nextBoundary, length * 2)
        }
    }

    func testEpochComesFromTheSameFrameAsProgressNotOlderRPC() {
        let snapshot = NodeSnapshot(lastReceivedFrame: 719, epoch: 0, nextEpochFrame: 720, frame: 721)
        XCTAssertEqual(snapshot.epochClock.epoch, 1)
        XCTAssertEqual(snapshot.epochClock.nextBoundary, 1440)
        XCTAssertEqual(snapshot.epochClock.framesRemaining, 719)
        XCTAssertEqual(snapshot.epochClock.progress, 1.0 / 720, accuracy: 0.00001)
    }

    func testZeroLengthMatchesTheUpstreamFallback() {
        XCTAssertEqual(NodeEpochClock(frame: 1000, epochLength: 0).epoch, 1)
        XCTAssertEqual(NodeEpochClock(frame: 1000, epochLength: 0).length, 720)
    }

    func testBoundaryOverflowIsUnknownRatherThanACrash() {
        for length: UInt64 in [1, 60, 720, .max] {
            let clock = NodeEpochClock(frame: .max, epochLength: length)
            XCTAssertNil(clock.nextBoundary)
            XCTAssertGreaterThan(clock.framesRemaining, 0)
        }
        XCTAssertNil(NodeEpochClock(frame: .max, epochLength: 1).nextEpoch)
    }

    func testProverFreshnessRejectsFailedFutureAndStaleReads() {
        let now = Date(timeIntervalSince1970: 1000)
        var snapshot = NodeSnapshot(isRunning: true, proverStatusUpdatedAt: now)
        XCTAssertTrue(snapshot.hasFreshProverStatus(at: now))
        XCTAssertFalse(snapshot.hasFreshProverStatus(at: now.addingTimeInterval(181)))
        XCTAssertFalse(snapshot.hasFreshProverStatus(at: now.addingTimeInterval(-1)))
        snapshot.proverStatusError = "Unavailable"
        XCTAssertFalse(snapshot.hasFreshProverStatus(at: now))
    }
}
