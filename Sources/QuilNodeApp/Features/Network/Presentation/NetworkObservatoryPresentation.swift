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

enum NetworkObservatoryLens: String, CaseIterable, Identifiable {
    case all
    case local
    case attention
    case largestStorage
    case highestReward
    case recentlyChanged

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All shards"
        case .local: "My allocations"
        case .attention: "Needs coverage"
        case .largestStorage: "Largest storage"
        case .highestReward: "Highest estimated reward"
        case .recentlyChanged: "Recently changed"
        }
    }

    var detail: String {
        switch self {
        case .all: "Every shard returned by this local qclient"
        case .local: "Only shards linked to this node"
        case .attention: "Unassigned or below the six-prover target"
        case .largestStorage: "Top 10 by locally reported storage"
        case .highestReward: "Top 10 protocol reward estimates"
        case .recentlyChanged: "Public metrics changed in the last 24 hours"
        }
    }

    var systemImage: String {
        switch self {
        case .all: "point.3.connected.trianglepath.dotted"
        case .local: "location.fill"
        case .attention: "exclamationmark.triangle.fill"
        case .largestStorage: "externaldrive.fill"
        case .highestReward: "sparkles"
        case .recentlyChanged: "clock.arrow.circlepath"
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

    func matches(_ query: String, includesLocalAssignments: Bool = true) -> Bool {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return true }
        let publicMatch =
            observation.filter.lowercased().contains(normalized)
            || coverage.label.lowercased().contains(normalized)
            || "ring \(observation.ring)".contains(normalized)
        guard !publicMatch, includesLocalAssignments else { return publicMatch }
        return observation.worker?.lowercased().contains(normalized) == true
            || "worker \(observation.worker ?? "")".contains(normalized)
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
    let epochProgress: Double
    let nextEpoch: UInt64?
    let observedAt: Date?
    let evidenceState: EvidenceState
    let isUsingSavedTopology: Bool
    let topologyIssue: String?
    let proverMemberships: Int
    let ringDistribution: NetworkRingDistribution
    let localNode: NetworkLocalNodePresentation

    static func make(
        snapshot: NodeSnapshot,
        cachedTopology: CachedNetworkShardTopology? = nil,
        now: Date = Date()
    ) -> Self {
        let liveShards = snapshot.networkShards ?? []
        let isUsingSavedTopology = liveShards.isEmpty && cachedTopology?.shards.isEmpty == false
        let sourceShards =
            isUsingSavedTopology
            ? NetworkTopologyFallbackPresentation.attachLocalAllocations(
                to: cachedTopology?.shards ?? [],
                allocations: snapshot.shardAllocations
            )
            : liveShards
        let shards =
            sourceShards
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
        let summary =
            isUsingSavedTopology
            ? NetworkShardSummary(
                shards: sourceShards,
                observedAt: cachedTopology?.observedAt ?? now
            )
            : snapshot.networkShardSummary
        let observedAt = summary?.observedAt
        let evidenceState: EvidenceState
        if isUsingSavedTopology || (snapshot.networkShardError != nil && !shards.isEmpty) {
            evidenceState = .stale
        } else if snapshot.networkShards == nil {
            evidenceState = snapshot.isRunning ? .loading : .unavailable
        } else if shards.isEmpty {
            evidenceState = .unavailable
        } else if let observedAt, now.timeIntervalSince(observedAt) > 180 {
            evidenceState = .stale
        } else {
            evidenceState = .current
        }

        let effectiveFrame = max(snapshot.epochClock.frame, summary?.frame ?? 0)
        let epochClock = NodeEpochClock(frame: effectiveFrame, epochLength: snapshot.epochLength)
        let topologyIssue = NetworkTopologyFallbackPresentation.issue(for: snapshot)

        let localNode = NetworkLocalNodePresentation.make(snapshot: snapshot, shards: shards)
        return Self(
            shards: shards,
            summary: summary,
            peers: snapshot.peers,
            archiveSources: snapshot.archiveEndpointCount,
            localAllocationCount: localNode.totalAllocations,
            frame: effectiveFrame,
            epoch: epochClock.epoch,
            epochProgress: epochClock.progress,
            nextEpoch: epochClock.nextEpoch,
            observedAt: observedAt,
            evidenceState: evidenceState,
            isUsingSavedTopology: isUsingSavedTopology,
            topologyIssue: topologyIssue,
            proverMemberships: shards.reduce(0) { $0 + max($1.observation.activeProvers, 0) },
            ringDistribution: NetworkRingDistribution(shards: shards),
            localNode: localNode
        )
    }

    func visibleShards(
        lens: NetworkObservatoryLens,
        query: String,
        includesLocalAssignments: Bool = true,
        recentChanges: [String: NetworkShardChangeRecord] = [:]
    ) -> [NetworkShardPresentation] {
        let scoped: [NetworkShardPresentation]
        switch lens {
        case .all:
            scoped = shards
        case .local:
            scoped = shards.filter(\.observation.isAllocated)
        case .attention:
            scoped = shards.filter { $0.coverage != .healthy }
        case .largestStorage:
            scoped = Array(shards.sorted(by: Self.storageOrder).prefix(10))
        case .highestReward:
            scoped = Array(shards.sorted(by: Self.rewardOrder).prefix(10))
        case .recentlyChanged:
            scoped =
                shards
                .filter { recentChanges[$0.id] != nil }
                .sorted { lhs, rhs in
                    let lhsDate = recentChanges[lhs.id]?.observedAt ?? .distantPast
                    let rhsDate = recentChanges[rhs.id]?.observedAt ?? .distantPast
                    if lhsDate != rhsDate { return lhsDate > rhsDate }
                    return lhs.fullFilter < rhs.fullFilter
                }
        }

        return scoped.filter {
            $0.matches(query, includesLocalAssignments: includesLocalAssignments)
        }
    }

    var preferredSelection: String? {
        shards.first(where: { $0.observation.isAllocated })?.id ?? shards.first?.id
    }

    /// Chooses the shards that deserve full visual treatment without hiding the
    /// rest of the locally observed network. Local allocations lead only when
    /// Privacy Mode permits that relationship to be shown.
    func featuredShardIDs(
        in candidates: [NetworkShardPresentation]? = nil,
        revealsLocalTopology: Bool,
        limit: Int = 9
    ) -> Set<String> {
        guard limit > 0 else { return [] }
        let ordered = (candidates ?? shards).sorted { lhs, rhs in
            let lhsPriority = visualPriority(lhs, revealsLocalTopology: revealsLocalTopology)
            let rhsPriority = visualPriority(rhs, revealsLocalTopology: revealsLocalTopology)
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }
            if lhs.observation.activeProvers != rhs.observation.activeProvers {
                return lhs.observation.activeProvers > rhs.observation.activeProvers
            }
            return lhs.fullFilter < rhs.fullFilter
        }
        return Set(ordered.prefix(limit).map(\.id))
    }

    var evidenceLabel: String {
        switch evidenceState {
        case .loading: "Reading local node"
        case .current: "Local observation current"
        case .stale: isUsingSavedTopology ? "Saved local observation" : "Last complete observation"
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

    private static func storageOrder(
        _ lhs: NetworkShardPresentation,
        _ rhs: NetworkShardPresentation
    ) -> Bool {
        let lhsValue = NetworkReportedQuantity.storageBytes(lhs.observation.shardSize)
        let rhsValue = NetworkReportedQuantity.storageBytes(rhs.observation.shardSize)
        if lhsValue != rhsValue {
            return (lhsValue ?? -1) > (rhsValue ?? -1)
        }
        return lhs.fullFilter < rhs.fullFilter
    }

    private static func rewardOrder(
        _ lhs: NetworkShardPresentation,
        _ rhs: NetworkShardPresentation
    ) -> Bool {
        let lhsValue = NetworkReportedQuantity.decimal(lhs.observation.estimatedRewardPerFrame)
        let rhsValue = NetworkReportedQuantity.decimal(rhs.observation.estimatedRewardPerFrame)
        if lhsValue != rhsValue {
            return (lhsValue ?? -1) > (rhsValue ?? -1)
        }
        return lhs.fullFilter < rhs.fullFilter
    }

    private func visualPriority(
        _ shard: NetworkShardPresentation,
        revealsLocalTopology: Bool
    ) -> Int {
        if revealsLocalTopology, shard.observation.isAllocated { return 0 }
        switch shard.coverage {
        case .atRisk: return 1
        case .belowTarget: return 2
        case .unassigned: return 3
        case .healthy: return 4
        }
    }
}

private enum NetworkReportedQuantity {
    private static let locale = Locale(identifier: "en_US_POSIX")

    static func decimal(_ value: String) -> Decimal? {
        Decimal(string: value.trimmingCharacters(in: .whitespacesAndNewlines), locale: locale)
    }

    static func storageBytes(_ value: String) -> Decimal? {
        let components = value.split(whereSeparator: \Character.isWhitespace)
        guard components.count == 2,
            let quantity = Decimal(string: String(components[0]), locale: locale),
            let multiplier = storageMultiplier(for: String(components[1]))
        else { return nil }
        return quantity * multiplier
    }

    private static func storageMultiplier(for unit: String) -> Decimal? {
        switch unit.uppercased() {
        case "B": 1
        case "KB": 1_000
        case "MB": 1_000_000
        case "GB": 1_000_000_000
        case "TB": 1_000_000_000_000
        case "PB": 1_000_000_000_000_000
        case "KIB": 1_024
        case "MIB": 1_048_576
        case "GIB": 1_073_741_824
        case "TIB": 1_099_511_627_776
        default: nil
        }
    }
}

private extension String {
    func shortenedIdentifier(prefix: Int, suffix: Int) -> String {
        guard count > prefix + suffix + 1 else { return self }
        return "\(self.prefix(prefix))…\(self.suffix(suffix))"
    }
}
