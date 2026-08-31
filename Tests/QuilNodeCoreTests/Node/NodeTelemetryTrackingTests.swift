import Foundation
import XCTest

@testable import QuilNodeCore

final class NodeTelemetryTrackingTests: XCTestCase {
    func testProcessorSamplerReportsWholeMachinePercentage() {
        let start = Date(timeIntervalSince1970: 1_000)
        var sampler = NodeProcessorUsageSampler(logicalCoreCount: 10)
        var first = NodeSnapshot(
            collectedAt: start,
            isRunning: true,
            processID: 42,
            cpuPercent: 200,
            processCPUTimeSeconds: 10,
            cpuSampledAt: start
        )
        sampler.apply(to: &first)
        XCTAssertEqual(first.cpuPercent, 20)
        XCTAssertEqual(first.cpuCoreEquivalent, 2)
        XCTAssertNil(first.cpuSampleWindowSeconds)

        var second = first
        second.processCPUTimeSeconds = 16
        second.cpuSampledAt = start.addingTimeInterval(2)
        sampler.apply(to: &second)
        XCTAssertEqual(second.cpuCoreEquivalent, 3)
        XCTAssertEqual(second.cpuPercent, 30)
        XCTAssertEqual(second.cpuSampleWindowSeconds, 2)
    }

    func testProcessorSamplerResetsAcrossProcessChanges() {
        let start = Date(timeIntervalSince1970: 1_000)
        var sampler = NodeProcessorUsageSampler(logicalCoreCount: 8)
        var snapshot = NodeSnapshot(
            isRunning: true,
            processID: 10,
            processCPUTimeSeconds: 50,
            cpuSampledAt: start
        )
        sampler.apply(to: &snapshot)

        snapshot.processID = 11
        snapshot.processCPUTimeSeconds = 1
        snapshot.cpuSampledAt = start.addingTimeInterval(2)
        snapshot.cpuPercent = 100
        sampler.apply(to: &snapshot)
        XCTAssertEqual(snapshot.cpuPercent, 12.5)
        XCTAssertEqual(snapshot.cpuCoreEquivalent, 1)
        XCTAssertNil(snapshot.cpuSampleWindowSeconds)
    }

    func testFrameTrackerWaitsForCredibleWindowAndTracksAdvance() {
        let start = Date(timeIntervalSince1970: 1_000)
        var tracker = NodeFrameProgressTracker()
        var snapshot = NodeSnapshot(collectedAt: start, isRunning: true, frame: 100)
        tracker.apply(to: &snapshot)
        XCTAssertNil(snapshot.framesPerMinute)
        XCTAssertEqual(snapshot.frameLastAdvancedAt, start)

        snapshot.collectedAt = start.addingTimeInterval(60)
        snapshot.frame = 106
        tracker.apply(to: &snapshot)
        XCTAssertNil(snapshot.framesPerMinute)

        snapshot.collectedAt = start.addingTimeInterval(120)
        snapshot.frame = 112
        tracker.apply(to: &snapshot)
        XCTAssertEqual(snapshot.framesPerMinute, 6)
        XCTAssertEqual(snapshot.lowerFramesPerMinute, 6)
        XCTAssertEqual(snapshot.upperFramesPerMinute, 6)
    }

    func testFrameTrackerClearsEvidenceWhenNodeStops() {
        var tracker = NodeFrameProgressTracker()
        var snapshot = NodeSnapshot(isRunning: true, frame: 100)
        tracker.apply(to: &snapshot)

        snapshot.isRunning = false
        tracker.apply(to: &snapshot)
        XCTAssertNil(snapshot.frameLastAdvancedAt)
        XCTAssertNil(snapshot.framesPerMinute)
        XCTAssertNil(snapshot.lowerFramesPerMinute)
        XCTAssertNil(snapshot.upperFramesPerMinute)
    }

    func testFrameTrackerClearsPaceAfterQuietInterval() {
        let start = Date(timeIntervalSince1970: 1000)
        var tracker = NodeFrameProgressTracker()
        var snapshot = NodeSnapshot(collectedAt: start, isRunning: true, frame: 100)
        tracker.apply(to: &snapshot)
        snapshot.collectedAt = start.addingTimeInterval(120)
        snapshot.frame = 112
        tracker.apply(to: &snapshot)
        XCTAssertEqual(snapshot.framesPerMinute, 6)
        snapshot.collectedAt = start.addingTimeInterval(240)
        tracker.apply(to: &snapshot)
        XCTAssertNil(snapshot.framesPerMinute)
        XCTAssertNil(snapshot.lowerFramesPerMinute)
        XCTAssertNil(snapshot.upperFramesPerMinute)
    }

    func testFrameRegressionRequiresANewPaceBaseline() {
        let start = Date(timeIntervalSince1970: 1000)
        var tracker = NodeFrameProgressTracker()
        var snapshot = NodeSnapshot(collectedAt: start, isRunning: true, frame: 100)
        tracker.apply(to: &snapshot)
        snapshot.collectedAt = start.addingTimeInterval(120)
        snapshot.frame = 120
        tracker.apply(to: &snapshot)
        snapshot.collectedAt = start.addingTimeInterval(150)
        snapshot.frame = 110
        tracker.apply(to: &snapshot)
        XCTAssertNil(snapshot.framesPerMinute)
        snapshot.collectedAt = start.addingTimeInterval(180)
        snapshot.frame = 112
        tracker.apply(to: &snapshot)
        XCTAssertNil(snapshot.framesPerMinute)
    }
}
