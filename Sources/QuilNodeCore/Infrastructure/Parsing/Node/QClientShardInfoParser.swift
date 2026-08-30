import Foundation
import QuilNodeShared

/// Parses the stable, human-readable output of `qclient node prover
/// shardinfo`. Parsing is intentionally isolated so upstream formatting drift
/// fails closed without affecting the node lifecycle monitor.
public enum QClientShardInfoParser {
    private static let rowExpression = try! NSRegularExpression(
        pattern:
            #"^\s*Filter:\s+([0-9a-fA-F]+)\s+Size:\s+(.+?)\s+Shards:\s+([0-9]+)\s+Provers:\s+([0-9]+)\s+Ring:\s+([0-9]+)\s+Reward:\s+~(.+?)\s+QUIL/frame(?:\s+\[(?:Worker\s+([^\]]+)|ACTIVE)\])?\s*$"#
    )
    private static let footerExpression = try! NSRegularExpression(
        pattern: #"^Difficulty:\s+([0-9]+)\s+Frame:\s+([0-9]+)\s*$"#
    )

    public static func parse(_ output: String) -> QClientShardInfoSnapshot? {
        var shards: [NetworkShardObservation] = []
        var frame: UInt64?
        var difficulty: UInt64?
        var worldState: String?

        for rawLine in output.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            if let shard = parseRow(line) {
                shards.append(shard)
                continue
            }
            if let values = captures(footerExpression, in: line), values.count == 2 {
                difficulty = UInt64(values[0])
                frame = UInt64(values[1])
                continue
            }
            if line.hasPrefix("World State:") {
                let value = line.dropFirst("World State:".count)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                worldState = value.isEmpty ? nil : value
            }
        }

        guard !shards.isEmpty else { return nil }
        return QClientShardInfoSnapshot(
            shards: shards,
            frame: frame,
            difficulty: difficulty,
            worldState: worldState
        )
    }

    private static func parseRow(_ line: String) -> NetworkShardObservation? {
        guard let values = captures(rowExpression, in: line), values.count == 7,
            let dataShards = Int(values[2]),
            let activeProvers = Int(values[3]),
            let ring = Int(values[4])
        else { return nil }
        let worker = values[6].isEmpty ? nil : values[6]
        return NetworkShardObservation(
            filter: values[0].lowercased(),
            shardSize: values[1],
            dataShards: dataShards,
            activeProvers: activeProvers,
            ring: ring,
            estimatedRewardPerFrame: values[5],
            isAllocated: worker != nil || line.contains("[ACTIVE]"),
            worker: worker
        )
    }

    private static func captures(_ expression: NSRegularExpression, in text: String) -> [String]? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = expression.firstMatch(in: text, range: range) else { return nil }
        return (1..<match.numberOfRanges).map { index in
            guard match.range(at: index).location != NSNotFound,
                let range = Range(match.range(at: index), in: text)
            else { return "" }
            return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

public enum LocalProverTelemetryParser {
    public static func parse(_ payload: QClientProverTelemetryPayload) -> LocalProverTelemetry? {
        guard var status = ProverStatusParser.parse(payload.statusOutput) else { return nil }
        let shardInfo = QClientShardInfoParser.parse(payload.shardInfoOutput)
        let byFilter = Dictionary(
            (shardInfo?.shards ?? []).map { ($0.filter.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        status.allocations = status.allocations.map { allocation in
            guard let shard = byFilter[allocation.filter.lowercased()] else { return allocation }
            var enriched = allocation
            enriched.activeProvers = shard.activeProvers
            enriched.ring = shard.ring
            enriched.estimatedRewardPerFrame = shard.estimatedRewardPerFrame
            enriched.shardSize = shard.shardSize
            enriched.dataShards = shard.dataShards
            if enriched.worker == nil { enriched.worker = shard.worker }
            return enriched
        }

        let summary = shardInfo.map {
            NetworkShardSummary(
                shards: $0.shards,
                frame: $0.frame,
                difficulty: $0.difficulty,
                worldState: $0.worldState,
                observedAt: payload.observedAt
            )
        }
        return LocalProverTelemetry(
            status: status,
            networkSummary: summary,
            observedAt: payload.observedAt
        )
    }
}
