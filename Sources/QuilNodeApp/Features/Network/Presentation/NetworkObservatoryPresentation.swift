import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

enum NetworkWorkspaceMode: String, CaseIterable, Identifiable {
    case observatory
    case connectivity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .observatory: "Observatory"
        case .connectivity: "Connectivity"
        }
    }

    var systemImage: String {
        switch self {
        case .observatory: "point.3.filled.connected.trianglepath.dotted"
        case .connectivity: "cable.connector"
        }
    }
}

enum NetworkObservatoryFilter: String, CaseIterable, Identifiable {
    case all
    case local
    case attention

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All shards"
        case .local: "My allocations"
        case .attention: "Needs coverage"
        }
    }
}

struct NetworkShardPresentation: Identifiable, Equatable {
    let observation: NetworkShardObservation

    var id: String { observation.id }
    var shortFilter: String { observation.filter.shortenedIdentifier(prefix: 6, suffix: 4) }
    var fullFilter: String { observation.filter }
    var coverage: ShardCoverageState { observation.coverageState }

    var title: String {
        observation.isAllocated ? "Allocated shard" : "Network shard"
    }

    var coverageDetail: String {
        switch coverage {
        case .healthy: "Meets the six-prover coverage target"
        case .belowTarget: "Below the six-prover coverage target"
        case .atRisk: "Within the protocol's low-coverage band"
        case .unassigned: "No active prover is reported"
        }
    }

    func matches(_ query: String) -> Bool {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return true }
        return observation.filter.lowercased().contains(normalized)
            || coverage.label.lowercased().contains(normalized)
            || "ring \(observation.ring)".contains(normalized)
    }
}

struct NetworkObservatoryPresentation {
    enum EvidenceState: Equatable {
        case loading
        case current
        case stale
        case unavailable
    }

    let shards: [NetworkShardPresentation]
    let summary: NetworkShardSummary?
    let peers: Int
    let archiveSources: Int?
    let localAllocationCount: Int
    let frame: UInt64
    let epoch: UInt64
    let observedAt: Date?
    let evidenceState: EvidenceState

    static func make(snapshot: NodeSnapshot, now: Date = Date()) -> Self {
        let shards = (snapshot.networkShards ?? [])
            .map(NetworkShardPresentation.init)
            .sorted { lhs, rhs in
                if lhs.observation.isAllocated != rhs.observation.isAllocated {
                    return lhs.observation.isAllocated
                }
                if coverageRank(lhs.coverage) != coverageRank(rhs.coverage) {
                    return coverageRank(lhs.coverage) < coverageRank(rhs.coverage)
                }
                return lhs.fullFilter < rhs.fullFilter
            }
        let observedAt = snapshot.networkShardSummary?.observedAt
        let evidenceState: EvidenceState
        if snapshot.networkShards == nil {
            evidenceState = snapshot.isRunning ? .loading : .unavailable
        } else if shards.isEmpty {
            evidenceState = .unavailable
        } else if let observedAt, now.timeIntervalSince(observedAt) > 180 {
            evidenceState = .stale
        } else {
            evidenceState = .current
        }

        return Self(
            shards: shards,
            summary: snapshot.networkShardSummary,
            peers: snapshot.peers,
            archiveSources: snapshot.archiveEndpointCount,
            localAllocationCount: snapshot.shardAllocations.count,
            frame: max(snapshot.frame, snapshot.networkShardSummary?.frame ?? 0),
            epoch: snapshot.epoch,
            observedAt: observedAt,
            evidenceState: evidenceState
        )
    }

    func visibleShards(filter: NetworkObservatoryFilter, query: String) -> [NetworkShardPresentation] {
        shards.filter { shard in
            let isIncluded =
                switch filter {
                case .all: true
                case .local: shard.observation.isAllocated
                case .attention: shard.coverage != .healthy
                }
            return isIncluded && shard.matches(query)
        }
    }

    var preferredSelection: String? {
        shards.first(where: { $0.observation.isAllocated })?.id ?? shards.first?.id
    }

    var evidenceLabel: String {
        switch evidenceState {
        case .loading: "Reading local node"
        case .current: "Local observation current"
        case .stale: "Last local observation"
        case .unavailable: "Topology unavailable"
        }
    }

    private static func coverageRank(_ state: ShardCoverageState) -> Int {
        switch state {
        case .unassigned: 0
        case .atRisk: 1
        case .belowTarget: 2
        case .healthy: 3
        }
    }
}

private extension String {
    func shortenedIdentifier(prefix: Int, suffix: Int) -> String {
        guard count > prefix + suffix + 1 else { return self }
        return "\(self.prefix(prefix))…\(self.suffix(suffix))"
    }
}
