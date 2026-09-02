import Foundation

/// Mainnet coverage bands from the node's protocol thresholds. "At risk" is
/// deliberately not called "halted": a low prover count starts a grace streak,
/// while an active halt requires separate runtime evidence.
public enum ShardCoverageState: String, Codable, Equatable, Sendable {
    case unassigned
    case atRisk
    case belowTarget
    case healthy

    public init(activeProvers: Int) {
        switch activeProvers {
        case ...0: self = .unassigned
        case 1...3: self = .atRisk
        case 4...5: self = .belowTarget
        default: self = .healthy
        }
    }

    public var label: String {
        switch self {
        case .unassigned: "Unassigned"
        case .atRisk: "At risk"
        case .belowTarget: "Below target"
        case .healthy: "Healthy"
        }
    }
}

public struct NetworkShardObservation: Codable, Equatable, Identifiable, Sendable {
    public var filter: String
    public var shardSize: String
    public var dataShards: Int
    public var activeProvers: Int
    public var ring: Int
    public var estimatedRewardPerFrame: String
    public var isAllocated: Bool
    public var worker: String?

    public var id: String { filter }

    public init(
        filter: String,
        shardSize: String,
        dataShards: Int,
        activeProvers: Int,
        ring: Int,
        estimatedRewardPerFrame: String,
        isAllocated: Bool,
        worker: String? = nil
    ) {
        self.filter = filter
        self.shardSize = shardSize
        self.dataShards = dataShards
        self.activeProvers = activeProvers
        self.ring = ring
        self.estimatedRewardPerFrame = estimatedRewardPerFrame
        self.isAllocated = isAllocated
        self.worker = worker
    }

    public var coverageState: ShardCoverageState {
        ShardCoverageState(activeProvers: activeProvers)
    }
}

public struct NetworkShardSummary: Codable, Equatable, Sendable {
    public var totalShards: Int
    public var healthyShards: Int
    public var belowTargetShards: Int
    public var atRiskShards: Int
    public var unassignedShards: Int
    public var frame: UInt64?
    public var difficulty: UInt64?
    public var worldState: String?
    public var observedAt: Date

    public init(
        shards: [NetworkShardObservation],
        frame: UInt64? = nil,
        difficulty: UInt64? = nil,
        worldState: String? = nil,
        observedAt: Date = Date()
    ) {
        totalShards = shards.count
        healthyShards = shards.count { $0.coverageState == .healthy }
        belowTargetShards = shards.count { $0.coverageState == .belowTarget }
        atRiskShards = shards.count { $0.coverageState == .atRisk }
        unassignedShards = shards.count { $0.coverageState == .unassigned }
        self.frame = frame
        self.difficulty = difficulty
        self.worldState = worldState
        self.observedAt = observedAt
    }
}

public struct QClientShardInfoSnapshot: Equatable, Sendable {
    public var shards: [NetworkShardObservation]
    public var frame: UInt64?
    public var difficulty: UInt64?
    public var worldState: String?

    public init(
        shards: [NetworkShardObservation],
        frame: UInt64? = nil,
        difficulty: UInt64? = nil,
        worldState: String? = nil
    ) {
        self.shards = shards
        self.frame = frame
        self.difficulty = difficulty
        self.worldState = worldState
    }
}

public struct LocalProverTelemetry: Equatable, Sendable {
    public var status: LocalProverStatus
    /// Full shard rows emitted by the local qclient. This is the source for
    /// topology views; it is not a remote census or an inferred peer graph.
    public var networkShards: [NetworkShardObservation]
    public var networkSummary: NetworkShardSummary?
    public var networkShardError: String?
    public var observedAt: Date

    public init(
        status: LocalProverStatus,
        networkShards: [NetworkShardObservation] = [],
        networkSummary: NetworkShardSummary? = nil,
        networkShardError: String? = nil,
        observedAt: Date
    ) {
        self.status = status
        self.networkShards = networkShards
        self.networkSummary = networkSummary
        self.networkShardError = networkShardError
        self.observedAt = observedAt
    }
}
