import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

enum NetworkObservatorySelection: Equatable {
    case localNode
    case shard(String)
}

struct NetworkRingDistribution: Equatable {
    let ring0: Int
    let ring1: Int
    let ring2: Int
    let ring3Plus: Int

    init(shards: [NetworkShardPresentation]) {
        ring0 = shards.count { $0.observation.ring == 0 }
        ring1 = shards.count { $0.observation.ring == 1 }
        ring2 = shards.count { $0.observation.ring == 2 }
        ring3Plus = shards.count { $0.observation.ring >= 3 }
    }

    var compactLabel: String {
        "R0 \(ring0) · R1 \(ring1) · R2 \(ring2) · R3+ \(ring3Plus)"
    }
}

struct LocalAllocationCoverageSummary: Equatable {
    let healthy: Int
    let belowTarget: Int
    let atRisk: Int
    let unassigned: Int

    init(states: [ShardCoverageState]) {
        healthy = states.count { $0 == .healthy }
        belowTarget = states.count { $0 == .belowTarget }
        atRisk = states.count { $0 == .atRisk }
        unassigned = states.count { $0 == .unassigned }
    }

    var needsCoverage: Int { belowTarget + atRisk + unassigned }
    var hasEvidence: Bool { healthy + needsCoverage > 0 }
}

/// A local-only operator dossier. Each field keeps its original evidence
/// boundary: worker runtime, allocation lifecycle, coverage and reward credit
/// are deliberately separate because none of them proves the others.
struct NetworkLocalNodePresentation {
    let isRunning: Bool
    let version: String?
    let runningWorkers: Int?
    let allocatedWorkers: Int
    let activeAllocations: Int
    let joiningAllocations: Int
    let totalAllocations: Int
    let allocationCoverage: LocalAllocationCoverageSummary
    let localRings: NetworkRingDistribution
    let participation: ParticipationEvidencePresentation
    let estimatedRewardPerFrame: String?
    let estimatedRewardPerTargetDay: String?
    let quilBalance: String?
    let lastRewardCreditFrame: UInt64?
    let lastRewardCreditAt: Date?
    let seniority: Int64
    let peerID: String?
    let proverAddress: String?
    let quilAccount: String?
    let framesPerMinute: Double?
    let inboundConnections: UInt64?
    let outboundConnections: UInt64?
    let cpuPercent: Double?
    let memoryMB: Double?
    let processUptime: String?
    let observedAt: Date?

    static func make(snapshot: NodeSnapshot, shards: [NetworkShardPresentation]) -> Self {
        let localShards = shards.filter(\.observation.isAllocated)
        let allocationCoverageStates: [ShardCoverageState]
        if !localShards.isEmpty {
            allocationCoverageStates = localShards.map(\.coverage)
        } else {
            allocationCoverageStates = snapshot.shardAllocations.compactMap(\.coverageState)
        }

        let estimate = RewardEstimate.make(localShards.map(\.observation.estimatedRewardPerFrame))
        return Self(
            isRunning: snapshot.isRunning,
            version: snapshot.version,
            runningWorkers: snapshot.localWorkerCount,
            allocatedWorkers: snapshot.allocatedWorkers,
            activeAllocations: snapshot.activeAllocations,
            joiningAllocations: snapshot.joiningAllocations,
            totalAllocations: max(
                snapshot.totalAllocations,
                snapshot.shardAllocations.count,
                localShards.count
            ),
            allocationCoverage: LocalAllocationCoverageSummary(states: allocationCoverageStates),
            localRings: NetworkRingDistribution(shards: localShards),
            participation: ParticipationEvidencePresentation.make(snapshot: snapshot),
            estimatedRewardPerFrame: estimate?.perFrame,
            estimatedRewardPerTargetDay: estimate?.perTargetDay,
            quilBalance: snapshot.quilBalance,
            lastRewardCreditFrame: snapshot.lastRewardCreditFrame,
            lastRewardCreditAt: snapshot.lastRewardCreditAt,
            seniority: snapshot.seniority,
            peerID: snapshot.peerID,
            proverAddress: snapshot.proverAddress,
            quilAccount: snapshot.quilAccount,
            framesPerMinute: snapshot.framesPerMinute,
            inboundConnections: snapshot.inboundConnectionsEstablished,
            outboundConnections: snapshot.outboundConnectionsEstablished,
            cpuPercent: snapshot.cpuPercent,
            memoryMB: snapshot.memoryMB,
            processUptime: snapshot.processUptime,
            observedAt: snapshot.proverStatusUpdatedAt ?? snapshot.metricsUpdatedAt ?? snapshot.collectedAt
        )
    }

    func matches(_ query: String, includesPrivateIdentifiers: Bool = true) -> Bool {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return true }
        let searchable =
            includesPrivateIdentifiers
            ? ["my node", "local node", version, peerID, proverAddress, quilAccount]
            : ["my node", "local node", version]
        return searchable.compactMap { $0?.lowercased() }.contains { $0.contains(normalized) }
    }
}

private struct RewardEstimate {
    /// The upstream qclient uses the protocol's ten-second target cadence when
    /// it prints a daily estimate: 8,640 target frames per day.
    private static let targetFramesPerDay = Decimal(8_640)

    let perFrame: String
    let perTargetDay: String

    static func make(_ values: [String]) -> Self? {
        let decimals = values.compactMap { Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX")) }
        guard !decimals.isEmpty else { return nil }
        let total = decimals.reduce(Decimal.zero, +)
        return Self(
            perFrame: format(total),
            perTargetDay: format(total * targetFramesPerDay)
        )
    }

    private static func format(_ value: Decimal) -> String {
        let number = NSDecimalNumber(decimal: value)
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = false
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 8
        return formatter.string(from: number) ?? number.stringValue
    }
}
