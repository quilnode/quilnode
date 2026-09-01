import Foundation
import XCTest

@testable import QuilNodeCore
@testable import QuilNodeShared

final class NodeIdentityAndParsingTests: XCTestCase {
    func testBalanceProverRegistryAndSeniorityParsing() {
        let balanceOutput = """
            Loading node config...
            QmExamplePeer
            Total balance: 132.500000000000 QUIL (Account 0x0123456789abcdef)
            """
        let balance = QuilBalanceParser.parse(balanceOutput)
        expect(balance?.amount == "132.500000000000", "QUIL balance parsing")
        expect(balance?.account == "0x0123456789abcdef", "QUIL account parsing")
        expect(QuilBalanceParser.parse("wallet unavailable") == nil, "invalid balance rejection")

        let proverStatusOutput = """
            Peer ID:            QmExamplePeer
            Version:            2.1.0.25
            Seniority:          12345678
            Peer Score:         99.5
            Running Workers:    3
            Allocated Workers:  3
            Last Received:      500004
            Last Global Head:   500004
            Epoch:              694  (length 720 frames; next boundary @ frame 500400)
            Reachable:          true

            Shard Allocations:
              [0] Filter: 00aabb  Status: Joining  Worker: worker-0
                  Action: Confirm in 20 frames | Reject in 20 frames
                  Join Frame: 499980 (epoch 694)  Confirm Frame: 500000
              [1] Filter: 11ccdd  Status: Active  Worker: worker-1
                  Re-confirm through epoch 694 (renew before frame 500400)
                  Last Active: 500003
            """
        if let prover = ProverStatusParser.parse(proverStatusOutput) {
            expect(prover.seniority == 12_345_678, "prover RPC seniority parsing")
            expect(prover.reachable == true, "prover reachability parsing")
            expect(prover.epoch == 694 && prover.epochLength == 720, "epoch clock parsing")
            expect(prover.nextEpochFrame == 500_400, "next epoch boundary parsing")
            expect(prover.allocations.count == 2, "shard allocation parsing")
            expect(prover.allocations.first?.status == "Joining", "allocation status parsing")
            expect(prover.allocations.first?.confirmFrame == 500_000, "allocation timing parsing")
            expect(prover.allocations.last?.lastActiveFrame == 500_003, "last active frame parsing")
        } else {
            XCTFail("local prover status parsing")
        }

        let registryLine =
            #"2030-01-02T05:06:07Z\tinfo\tprover_registry.rs:1145\tlocal prover appeared in registry\t{"address":"deadbeefcafefeed","allocations":3,"seniority":12345678,"status":"Joining"}"#
        if let registry = LocalRegistryParser.parse(registryLine) {
            expect(registry.proverAddress == "deadbeefcafefeed", "local registry address parsing")
            expect(registry.seniority == 12_345_678, "local registry seniority parsing")
            expect(registry.allocations == 3, "local registry allocation parsing")
            expect(registry.status == "Joining", "local registry lifecycle parsing")
        } else {
            XCTFail("local registry evidence parsing")
        }

        let seniorityChangeLine =
            #"2030-01-02T05:16:07Z\tinfo\tquil_execution/src/prover_registry.rs:1181\tlocal prover seniority changed\t{"address":"deadbeefcafefeed","coreId":0,"new":12345688,"prev":12345678}"#
        if let change = LocalRegistryParser.parse(seniorityChangeLine) {
            expect(change.seniority == 12_345_688, "chain seniority change parsing")
            expect(change.previousSeniority == 12_345_678, "previous chain seniority parsing")
            expect(change.kind == .valueChanged, "chain seniority evidence kind")
            expect(change.observedAt != nil, "chain seniority evidence timestamp")
        } else {
            XCTFail("chain seniority change evidence parsing")
        }
        expect(
            LocalRegistryParser.latest(in: registryLine + "\n" + seniorityChangeLine)?.seniority == 12_345_688,
            "latest chain seniority evidence selection"
        )

        let trendNow = ISO8601DateFormatter().date(from: "2030-01-02T06:00:00Z")!
        let increasingTrend = SeniorityTrend.evaluate(
            currentValue: 12_345_688,
            previousValue: 12_345_678,
            currentObservedAt: ISO8601DateFormatter().date(from: "2030-01-02T05:16:07Z"),
            samples: [],
            now: trendNow
        )
        expect(increasingTrend.direction == .increased, "seniority increase trend")
        expect(increasingTrend.delta == 10, "seniority increase delta")

        let unchangedTrend = SeniorityTrend.evaluate(
            currentValue: 12_345_688,
            previousValue: nil,
            currentObservedAt: trendNow.addingTimeInterval(-2 * 60 * 60),
            samples: [],
            now: trendNow
        )
        expect(unchangedTrend.direction == .unchanged, "seniority unchanged trend")

    }

    func testLocalQClientShardTopologyAndCoverageParsing() {
        let statusOutput = """
            Peer ID:            QmExamplePeer
            Version:            2.1.0.25
            Seniority:          12345678
            Peer Score:         91.2
            Running Workers:    3
            Allocated Workers:  2
            Last Received:      766956
            Last Global Head:   766956
            Epoch:              1065  (length 720 frames; next boundary @ frame 767520)
            Reachable:          true

            Shard Allocations:
              [0] Filter: 00aabb  Status: active  Worker: 2
                  Last Active: 766955
              [1] Filter: 11ccdd  Status: joining  Worker: 3
                  Join Frame: 766900 (epoch 1065)
            """
        let shardInfoOutput = """
            All Shards (4 shards):
              Filter: 00aabb  Size: 12.4 GB    Shards: 2      Provers: 3    Ring: 0  Reward: ~0.0012 QUIL/frame  [Worker 2]
              Filter: 11ccdd  Size: 8.0 GB     Shards: 1      Provers: 5    Ring: 1  Reward: ~0.0007 QUIL/frame  [Worker 3]
              Filter: 22eeff  Size: 4.0 GB     Shards: 1      Provers: 6    Ring: 0  Reward: ~0.0005 QUIL/frame
              Filter: 33aaff  Size: 2.0 GB     Shards: 1      Provers: 0    Ring: 0  Reward: ~0 QUIL/frame

            Difficulty: 12345  Frame: 766956
            World State: 75.36 GB
            """
        let observedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let payload = QClientProverTelemetryPayload(
            statusOutput: statusOutput,
            shardInfoOutput: shardInfoOutput,
            observedAt: observedAt
        )

        guard let telemetry = LocalProverTelemetryParser.parse(payload) else {
            return XCTFail("local qclient telemetry parsing")
        }
        expect(telemetry.status.allocations.count == 2, "local allocation count")
        expect(telemetry.status.allocations[0].worker == "2", "worker mapping")
        expect(telemetry.status.allocations[0].ring == 0, "local allocation ring")
        expect(telemetry.status.allocations[0].activeProvers == 3, "local prover count")
        expect(telemetry.status.allocations[0].coverageState == .atRisk, "halt-threshold band")
        expect(telemetry.status.allocations[1].coverageState == .belowTarget, "below-target band")
        expect(telemetry.networkShards.count == 4, "full shard topology retained")
        expect(telemetry.networkShards[0].filter == "00aabb", "shard identity retained")
        expect(telemetry.networkShards[0].isAllocated, "local allocation marker retained")
        expect(!telemetry.networkShards[2].isAllocated, "unallocated shard marker retained")
        expect(telemetry.networkSummary?.totalShards == 4, "network shard total")
        expect(telemetry.networkSummary?.healthyShards == 1, "healthy coverage count")
        expect(telemetry.networkSummary?.belowTargetShards == 1, "below-target coverage count")
        expect(telemetry.networkSummary?.atRiskShards == 1, "at-risk coverage count")
        expect(telemetry.networkSummary?.unassignedShards == 1, "unassigned coverage count")
        expect(telemetry.networkSummary?.frame == 766_956, "shard topology frame")
        expect(telemetry.networkSummary?.worldState == "75.36 GB", "world-state size")
        expect(telemetry.networkSummary?.observedAt == observedAt, "topology observation time")

        expect(ShardCoverageState(activeProvers: 0) == .unassigned, "zero-prover coverage band")
        expect(ShardCoverageState(activeProvers: 3) == .atRisk, "inclusive halt threshold")
        expect(ShardCoverageState(activeProvers: 4) == .belowTarget, "coverage recovery band")
        expect(ShardCoverageState(activeProvers: 5) == .belowTarget, "minimum target boundary")
        expect(ShardCoverageState(activeProvers: 6) == .healthy, "healthy coverage boundary")
    }
}
