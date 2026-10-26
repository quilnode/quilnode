import QuilNodeShared
import XCTest

@testable import QuilNodeCore

final class QClientShardFormatTests: XCTestCase {
    func testDailyRewardsAndUnknownRingsPreserveTheirUnitsAndMissingEvidence() throws {
        let output = """
            All Shards (3 shards):
              Filter: aabb  Size: 1.6 GB  Shards: 12  Provers: 25  Ring: 1  Reward: 33 Q/d  [Worker 2]
              Filter: ccdd  Size: 0 B  Shards: 0  Provers: 6  Ring: -  Reward: - Q/d  [ACTIVE]
              Filter: eeff  Size: 4 GB  Shards: 2  Provers: 7  Ring: 0  Reward: ~0.001 QUIL/frame
            Difficulty: 123 Frame: 935950
            World State: 75.36 GB
            """
        let parsed = try XCTUnwrap(QClientShardInfoParser.parse(output))
        XCTAssertEqual(parsed.shards.count, 3)
        XCTAssertEqual(parsed.shards[0].estimatedRewardPerDay, "33")
        XCTAssertNil(parsed.shards[0].estimatedRewardPerFrame)
        XCTAssertEqual(parsed.shards[0].rewardPerTargetDay, Decimal(33))
        XCTAssertEqual(parsed.shards[0].worker, "2")
        XCTAssertNil(parsed.shards[1].ring)
        XCTAssertEqual(parsed.shards[1].ringLabel, "Unknown")
        XCTAssertNil(parsed.shards[1].rewardPerTargetDay)
        XCTAssertTrue(parsed.shards[1].isAllocated)
        XCTAssertEqual(parsed.shards[2].estimatedRewardPerFrame, "0.001")
        XCTAssertEqual(parsed.shards[2].rewardPerTargetDay, Decimal(string: "8.64"))
        XCTAssertEqual(parsed.frame, 935_950)
    }

    func testTimeoutIsNotReportedAsAFormattingError() throws {
        let payload = QClientProverTelemetryPayload(
            statusOutput: "Seniority: 42", shardInfoOutput: "", observedAt: Date(),
            shardInfoError: "The local shard lookup timed out."
        )
        let result = try XCTUnwrap(LocalProverTelemetryParser.parse(payload))
        XCTAssertEqual(result.status.seniority, 42)
        XCTAssertEqual(result.networkShardError, payload.shardInfoError)
        XCTAssertTrue(result.networkShards.isEmpty)
    }

    func testUnsupportedRewardUnitsAreNotSilentlyConverted() {
        XCTAssertNil(
            QClientShardInfoParser.parse(
                "Filter: aabb Size: 1 GB Shards: 1 Provers: 6 Ring: 0 Reward: 99 QUIL/hour"
            ))
    }

    func testOldCachedRowsDecodeWithoutDailyRewardField() throws {
        let data = Data(
            #"{"filter":"aabb","shardSize":"1 GB","dataShards":1,"activeProvers":6,"ring":0,"estimatedRewardPerFrame":"0.001","isAllocated":false}"#
                .utf8)
        let observation = try JSONDecoder().decode(NetworkShardObservation.self, from: data)
        XCTAssertEqual(observation.ring, 0)
        XCTAssertNil(observation.estimatedRewardPerDay)
        XCTAssertEqual(observation.rewardPerTargetDay, Decimal(string: "8.64"))
    }
}
