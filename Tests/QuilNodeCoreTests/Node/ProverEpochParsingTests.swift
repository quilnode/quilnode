import XCTest

@testable import QuilNodeCore

final class ProverEpochParsingTests: XCTestCase {
    func testPreservesRenewalAndDepartureEvidenceFromRealCLIGrammar() throws {
        let output = """
            Last Received: 1500
            Epoch: 2 (length 720 frames; next boundary @ frame 2160)
            [0] Filter: aabb Status: active Worker: 1
              Re-confirm through epoch 3 (renew before frame 2160)
              Join Frame: 10 (epoch 0) Confirm Frame: 800
            [1] Filter: ccdd Status: re-confirm!
              MISSED re-confirm (registered epoch 1 < current 2) — confirm now to restore
            [2] Filter: eeff Status: expiredLeave
              Leave Frame: 10 (epoch 0) Confirm Frame: 800
            """
        let parsed = try XCTUnwrap(ProverStatusParser.parse(output))
        XCTAssertEqual(parsed.epoch, 2)
        XCTAssertEqual(parsed.nextEpochFrame, 2160)
        XCTAssertEqual(parsed.allocations[0].registeredEpoch, 3)
        XCTAssertEqual(parsed.allocations[0].joinFrame, 10)
        XCTAssertEqual(parsed.allocations[0].confirmFrame, 800)
        XCTAssertEqual(parsed.allocations[1].registeredEpoch, 1)
        XCTAssertTrue(parsed.allocations[1].action?.hasPrefix("MISSED re-confirm") == true)
        XCTAssertEqual(parsed.allocations[2].leaveFrame, 10)
        XCTAssertEqual(parsed.allocations[2].leaveConfirmFrame, 800)
        XCTAssertNil(parsed.allocations[2].confirmFrame)
    }

    func testEmptyAllocationListAndZeroLengthRemainValidTelemetry() throws {
        let output = """
            Last Received: 1000
            Epoch: 1 (length 0 frames; next boundary @ frame 1440)
            No shard allocations
            """
        let parsed = try XCTUnwrap(ProverStatusParser.parse(output))
        XCTAssertEqual(parsed.epochLength, 720)
        XCTAssertTrue(parsed.allocations.isEmpty)
    }

    func testMalformedFieldDoesNotConsumeALaterFieldsNumber() throws {
        let output = """
            [0] Filter: aa Status: joining
              Join Frame: unavailable (epoch 4) Confirm Frame: 3000
            """
        let parsed = try XCTUnwrap(ProverStatusParser.parse(output))
        XCTAssertNil(parsed.allocations[0].joinFrame)
        XCTAssertEqual(parsed.allocations[0].confirmFrame, 3000)
    }

    func testPreviousSnapshotsDecodeWithoutNewOptionalFields() throws {
        let data = Data(#"{"index":0,"filter":"aa","status":"joining","joinFrame":100}"#.utf8)
        let allocation = try JSONDecoder().decode(ShardAllocation.self, from: data)
        XCTAssertNil(allocation.registeredEpoch)
        XCTAssertNil(allocation.leaveFrame)
        XCTAssertNil(allocation.leaveConfirmFrame)
    }
}
