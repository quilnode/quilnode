import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

extension UInt64 {
    var grouped: String { formatted(.number.grouping(.automatic)) }
}

extension Int64 {
    var grouped: String { formatted(.number.grouping(.automatic)) }
}

extension String {
    var compactDecimal: String {
        guard contains(".") else { return self }
        var result = self
        while result.last == "0" { result.removeLast() }
        if result.last == "." { result.removeLast() }
        return result.isEmpty ? "0" : result
    }

    var compactIdentifier: String {
        guard count > 16 else { return self }
        return "\(prefix(8))…\(suffix(8))"
    }
}

extension NodeSnapshot {
    var workDetail: String {
        if !isRunning { return "The local node process is stopped" }
        if ChainProgressEvaluator.evaluate(self).state == .archiveRecovery {
            return "Serving active shards · waiting for archive recovery"
        }
        if activeShards > 0 {
            let rewards = lastRewardCreditFrame == nil ? "rewards pending" : "rewards credited"
            return "Serving active shards · \(rewards)"
        }
        if health == .stalled { return "Frame progress has stopped" }
        if pendingJoins > 0 { return "Joining shard allocations — not active yet" }
        return "Connected and waiting for a shard allocation"
    }
}
