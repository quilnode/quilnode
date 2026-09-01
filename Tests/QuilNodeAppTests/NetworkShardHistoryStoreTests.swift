import Foundation
import XCTest

@testable import QuilNodeApp
@testable import QuilNodeCore

@MainActor
final class NetworkShardHistoryStoreTests: XCTestCase {
    func testFirstObservationCreatesBaselineWithoutInventingChanges() {
        let store = NetworkShardHistoryStore(fileURL: nil)

        store.observe([shard("alpha")], observedAt: date(100))

        XCTAssertTrue(store.hasBaseline)
        XCTAssertTrue(store.recentChanges.isEmpty)
    }

    func testTracksOnlyChangedPublicShardMetrics() {
        let store = NetworkShardHistoryStore(fileURL: nil)
        store.observe([shard("alpha"), shard("stable")], observedAt: date(100))

        store.observe(
            [shard("alpha", provers: 4, ring: 1), shard("stable")],
            observedAt: date(200)
        )

        XCTAssertEqual(
            store.recentChanges["alpha"]?.fields,
            [.activeProvers, .ring]
        )
        XCTAssertNil(store.recentChanges["stable"])
    }

    func testIgnoresPrivateAllocationAndWorkerChanges() {
        let store = NetworkShardHistoryStore(fileURL: nil)
        store.observe([shard("alpha", allocated: false, worker: nil)], observedAt: date(100))

        store.observe([shard("alpha", allocated: true, worker: "9")], observedAt: date(200))

        XCTAssertTrue(store.recentChanges.isEmpty)
    }

    func testPersistsBaselineAndRecentChangesAcrossLaunches() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("quilnode-shard-history-\(UUID().uuidString)", isDirectory: true)
        let fileURL = directory.appendingPathComponent("history.json")
        defer { try? FileManager.default.removeItem(at: directory) }

        let first = NetworkShardHistoryStore(fileURL: fileURL, now: { self.date(250) })
        first.observe([shard("alpha")], observedAt: date(100))
        first.observe([shard("alpha", provers: 4)], observedAt: date(200))

        let restored = NetworkShardHistoryStore(fileURL: fileURL, now: { self.date(250) })

        XCTAssertTrue(restored.hasBaseline)
        XCTAssertEqual(restored.recentChanges["alpha"]?.fields, [.activeProvers])
    }

    func testExpiresChangesAfterTwentyFourHours() {
        let store = NetworkShardHistoryStore(fileURL: nil)
        store.observe([shard("alpha")], observedAt: date(100))
        store.observe([shard("alpha", provers: 4)], observedAt: date(200))

        XCTAssertTrue(store.changes(at: date(200 + 86_399)).keys.contains("alpha"))
        XCTAssertFalse(store.changes(at: date(200 + 86_401)).keys.contains("alpha"))
    }

    private func shard(
        _ filter: String,
        provers: Int = 6,
        ring: Int = 0,
        allocated: Bool = false,
        worker: String? = nil
    ) -> NetworkShardObservation {
        NetworkShardObservation(
            filter: filter,
            shardSize: "4 GB",
            dataShards: 1,
            activeProvers: provers,
            ring: ring,
            estimatedRewardPerFrame: "0.001",
            isAllocated: allocated,
            worker: worker
        )
    }

    private func date(_ seconds: TimeInterval) -> Date {
        Date(timeIntervalSince1970: 1_800_000_000 + seconds)
    }
}
