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
    var archiveSourceValue: String {
        archiveEndpointCount.map(String.init) ?? "—"
    }

    var archiveServiceValue: String {
        guard isRunning else { return "Offline" }
        guard archiveEndpointCount != nil else { return "Checking" }
        guard let evidence = freshArchiveEvidence else { return "Checking" }
        if evidence.archiveRPCStandby > 0 { return "Not needed" }
        if evidence.archiveConnections > 0 { return "Connected" }
        if evidence.archiveConnectionFailures >= max(archiveEndpointCount ?? 0, 1) { return "Unavailable" }
        return "Checking"
    }

    var archiveServiceDetail: String {
        let sources = archiveEndpointCount.map(String.init) ?? "Unknown"
        switch archiveServiceValue {
        case "Not needed": return "\(sources) known · gossip healthy"
        case "Connected": return "\(sources) known · archive link active"
        case "Unavailable": return "\(sources) known · connection failed"
        case "Offline": return "Node is stopped"
        default: return "\(sources) known · checking archive access"
        }
    }

    var archiveSourceDetail: String {
        switch archiveServiceValue {
        case "Not needed": "Known · gossip healthy"
        case "Connected": "Known · archive link active"
        case "Unavailable": "Known · access unavailable"
        case "Offline": "Node is stopped"
        default: "Known · checking access"
        }
    }

    var archiveProverStateValue: String {
        guard let evidence = chainProgressEvidence,
            Date().timeIntervalSince(evidence.observedAt) <= ChainProgressLogParser.observationWindow
        else {
            return "Monitoring"
        }
        return evidence.recoverySignalCount > 0 ? "Waiting" : "Monitoring"
    }

    var archiveProverStateDetail: String {
        archiveProverStateValue == "Waiting"
            ? "No source currently matches the required root"
            : "No current incompatibility reported"
    }

    private var freshArchiveEvidence: ChainProgressEvidence? {
        guard let evidence = chainProgressEvidence,
            Date().timeIntervalSince(evidence.observedAt) <= ChainProgressLogParser.observationWindow
        else {
            return nil
        }
        return evidence
    }

    var workDetail: String {
        if !isRunning { return "The local node process is stopped" }
        if ChainProgressEvaluator.evaluate(self).state == .archiveRecovery {
            return "Active registry allocations · waiting for archive recovery"
        }
        if activeShards > 0 {
            let rewards = lastRewardCreditFrame == nil ? "no reward credit observed" : "reward credit observed"
            return "Active registry allocations · \(rewards)"
        }
        if health == .stalled { return "Frame progress has stopped" }
        if pendingJoins > 0 { return "Joining shard allocations — not active yet" }
        return "Connected and waiting for a shard allocation"
    }
}
