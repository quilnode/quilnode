import Foundation

public enum NodeHealth: String, Codable, Sendable {
    case stopped
    case syncing
    case joining
    case active
    case stalled

    public var label: String {
        switch self {
        case .stopped: "Offline"
        case .syncing: "Online · Waiting"
        case .joining: "Joining Shards"
        case .active: "Allocations Active"
        case .stalled: "Stalled"
        }
    }

    public var systemImage: String {
        switch self {
        case .stopped: "stop.circle.fill"
        case .syncing: "arrow.triangle.2.circlepath.circle.fill"
        case .joining: "clock.badge.checkmark.fill"
        case .active: "checkmark.circle.fill"
        case .stalled: "exclamationmark.triangle.fill"
        }
    }
}

/// Where the operator-facing seniority value was obtained. QuilNode never
/// estimates seniority from elapsed frames: it presents only a value emitted
/// by the official node's current consensus view.
public enum SeniorityEvidenceSource: String, Codable, Sendable {
    case consensusRegistry
    case nodeDiagnostic
}

/// The kind of observation that established the current seniority value.
public enum SeniorityEvidenceKind: String, Codable, Sendable {
    case registrySnapshot
    case valueChanged
    case diagnostic
}

public struct NodeSnapshot: Codable, Equatable, Sendable {
    public var collectedAt: Date
    public var isRunning: Bool
    public var processID: Int32?
    public var version: String?
    public var peerID: String?
    public var legacyPeerID: String?
    public var proverAddress: String?
    public var quilBalance: String?
    public var quilAccount: String?
    public var balanceUpdatedAt: Date?
    public var balanceError: String?
    public var rewardBalanceSubunits: String?
    public var lastRewardCreditFrame: UInt64?
    public var lastRewardCreditAt: Date?
    public var proverStatusUpdatedAt: Date?
    public var proverStatusError: String?
    public var seniority: Int64
    public var previousSeniority: Int64?
    public var seniorityUpdatedAt: Date?
    public var seniorityEvidenceSource: SeniorityEvidenceSource?
    public var seniorityEvidenceKind: SeniorityEvidenceKind?
    public var peerScore: Double?
    public var reachable: Bool?
    public var allocatedWorkers: Int
    public var lastReceivedFrame: UInt64
    public var lastGlobalHeadFrame: UInt64
    public var epoch: UInt64
    public var epochLength: UInt64
    public var nextEpochFrame: UInt64
    public var shardAllocations: [ShardAllocation]
    /// Complete shard rows from the most recent local qclient observation.
    /// Optional storage keeps snapshots written by older app versions
    /// decodable while distinguishing "not collected" from an empty network.
    public var networkShards: [NetworkShardObservation]?
    public var networkShardSummary: NetworkShardSummary?
    public var frame: UInt64
    public var peers: Int
    /// Successful libp2p connections accepted by this node since the current
    /// process started. A non-zero value is strong local evidence that at
    /// least one remote peer crossed the router/firewall boundary.
    public var inboundConnectionsEstablished: UInt64?
    public var outboundConnectionsEstablished: UInt64?
    /// Local `.25` thread workers are discovered from the node's own log. The
    /// value is used only to explain capacity; it is not required for master
    /// port forwarding because thread workers do not open worker ports.
    public var localWorkerCount: Int?
    /// Signed, allowlisted archive identities announced through PeerInfo since
    /// the current node process started. This is a discovery counter, not a
    /// reachability probe.
    public var archivePeers: Int
    /// Archive RPC endpoints currently known by the node's local sync pool.
    /// `nil` means the installed node has not emitted enough evidence yet.
    public var archiveEndpointCount: Int?
    /// Effective `joining` allocation records reported by
    /// `qclient node prover status`. This is an allocation lifecycle count,
    /// not a worker-runtime health count.
    public var pendingJoins: Int
    /// Effective `active` allocation records reported by
    /// `qclient node prover status`. The historic property name is retained
    /// for persisted snapshot compatibility; operator-facing code should use
    /// `activeAllocations` below.
    public var activeShards: Int
    public var totalAllocations: Int
    public var framesReceived: UInt64
    public var routerDrops: UInt64
    /// Node CPU use as a percentage of the Mac's total logical CPU capacity.
    /// This is intentionally bounded to 0...100 for an operator-facing gauge.
    public var cpuPercent: Double?
    /// Logical cores consumed by the node over the current sampling window.
    public var cpuCoreEquivalent: Double?
    /// Cumulative user + system CPU time used to calculate interval load.
    public var processCPUTimeSeconds: Double?
    public var cpuSampledAt: Date?
    public var cpuSampleWindowSeconds: Double?
    public var memoryMB: Double?
    public var processUptime: String?
    public var logLastModifiedAt: Date?
    public var metricsUpdatedAt: Date?
    public var frameLastAdvancedAt: Date?
    public var framesPerMinute: Double?
    /// Robust interquartile bounds from recent local frame-advance samples.
    public var lowerFramesPerMinute: Double?
    public var upperFramesPerMinute: Double?
    /// Successful protocol transitions observed in the local node log, keyed
    /// by the upstream executable constant name.
    public var observedProtocolMilestones: [String: UInt64]?
    /// Recent, bounded archive synchronization evidence from the local log.
    public var chainProgressEvidence: ChainProgressEvidence?
    public var recentWarnings: [String]

    public init(
        collectedAt: Date = Date(),
        isRunning: Bool = false,
        processID: Int32? = nil,
        version: String? = nil,
        peerID: String? = nil,
        legacyPeerID: String? = nil,
        proverAddress: String? = nil,
        quilBalance: String? = nil,
        quilAccount: String? = nil,
        balanceUpdatedAt: Date? = nil,
        balanceError: String? = nil,
        rewardBalanceSubunits: String? = nil,
        lastRewardCreditFrame: UInt64? = nil,
        lastRewardCreditAt: Date? = nil,
        proverStatusUpdatedAt: Date? = nil,
        proverStatusError: String? = nil,
        seniority: Int64 = 0,
        previousSeniority: Int64? = nil,
        seniorityUpdatedAt: Date? = nil,
        seniorityEvidenceSource: SeniorityEvidenceSource? = nil,
        seniorityEvidenceKind: SeniorityEvidenceKind? = nil,
        peerScore: Double? = nil,
        reachable: Bool? = nil,
        allocatedWorkers: Int = 0,
        lastReceivedFrame: UInt64 = 0,
        lastGlobalHeadFrame: UInt64 = 0,
        epoch: UInt64 = 0,
        epochLength: UInt64 = 720,
        nextEpochFrame: UInt64 = 0,
        shardAllocations: [ShardAllocation] = [],
        networkShards: [NetworkShardObservation]? = nil,
        networkShardSummary: NetworkShardSummary? = nil,
        frame: UInt64 = 0,
        peers: Int = 0,
        inboundConnectionsEstablished: UInt64? = nil,
        outboundConnectionsEstablished: UInt64? = nil,
        localWorkerCount: Int? = nil,
        archivePeers: Int = 0,
        archiveEndpointCount: Int? = nil,
        pendingJoins: Int = 0,
        activeShards: Int = 0,
        totalAllocations: Int = 0,
        framesReceived: UInt64 = 0,
        routerDrops: UInt64 = 0,
        cpuPercent: Double? = nil,
        cpuCoreEquivalent: Double? = nil,
        processCPUTimeSeconds: Double? = nil,
        cpuSampledAt: Date? = nil,
        cpuSampleWindowSeconds: Double? = nil,
        memoryMB: Double? = nil,
        processUptime: String? = nil,
        logLastModifiedAt: Date? = nil,
        metricsUpdatedAt: Date? = nil,
        frameLastAdvancedAt: Date? = nil,
        framesPerMinute: Double? = nil,
        lowerFramesPerMinute: Double? = nil,
        upperFramesPerMinute: Double? = nil,
        observedProtocolMilestones: [String: UInt64]? = nil,
        chainProgressEvidence: ChainProgressEvidence? = nil,
        recentWarnings: [String] = []
    ) {
        self.collectedAt = collectedAt
        self.isRunning = isRunning
        self.processID = processID
        self.version = version
        self.peerID = peerID
        self.legacyPeerID = legacyPeerID
        self.proverAddress = proverAddress
        self.quilBalance = quilBalance
        self.quilAccount = quilAccount
        self.balanceUpdatedAt = balanceUpdatedAt
        self.balanceError = balanceError
        self.rewardBalanceSubunits = rewardBalanceSubunits
        self.lastRewardCreditFrame = lastRewardCreditFrame
        self.lastRewardCreditAt = lastRewardCreditAt
        self.proverStatusUpdatedAt = proverStatusUpdatedAt
        self.proverStatusError = proverStatusError
        self.seniority = seniority
        self.previousSeniority = previousSeniority
        self.seniorityUpdatedAt = seniorityUpdatedAt
        self.seniorityEvidenceSource = seniorityEvidenceSource
        self.seniorityEvidenceKind = seniorityEvidenceKind
        self.peerScore = peerScore
        self.reachable = reachable
        self.allocatedWorkers = allocatedWorkers
        self.lastReceivedFrame = lastReceivedFrame
        self.lastGlobalHeadFrame = lastGlobalHeadFrame
        self.epoch = epoch
        self.epochLength = epochLength
        self.nextEpochFrame = nextEpochFrame
        self.shardAllocations = shardAllocations
        self.networkShards = networkShards
        self.networkShardSummary = networkShardSummary
        self.frame = frame
        self.peers = peers
        self.inboundConnectionsEstablished = inboundConnectionsEstablished
        self.outboundConnectionsEstablished = outboundConnectionsEstablished
        self.localWorkerCount = localWorkerCount
        self.archivePeers = archivePeers
        self.archiveEndpointCount = archiveEndpointCount
        self.pendingJoins = pendingJoins
        self.activeShards = activeShards
        self.totalAllocations = totalAllocations
        self.framesReceived = framesReceived
        self.routerDrops = routerDrops
        self.cpuPercent = cpuPercent
        self.cpuCoreEquivalent = cpuCoreEquivalent
        self.processCPUTimeSeconds = processCPUTimeSeconds
        self.cpuSampledAt = cpuSampledAt
        self.cpuSampleWindowSeconds = cpuSampleWindowSeconds
        self.memoryMB = memoryMB
        self.processUptime = processUptime
        self.logLastModifiedAt = logLastModifiedAt
        self.metricsUpdatedAt = metricsUpdatedAt
        self.frameLastAdvancedAt = frameLastAdvancedAt
        self.framesPerMinute = framesPerMinute
        self.lowerFramesPerMinute = lowerFramesPerMinute
        self.upperFramesPerMinute = upperFramesPerMinute
        self.observedProtocolMilestones = observedProtocolMilestones
        self.chainProgressEvidence = chainProgressEvidence
        self.recentWarnings = recentWarnings
    }

    public static let empty = NodeSnapshot()

    /// Semantically precise aliases for the legacy persisted field names.
    /// A running worker can own an allocation that is still joining, so these
    /// values must never be presented as worker health.
    public var activeAllocations: Int { activeShards }
    public var joiningAllocations: Int { pendingJoins }

    public var health: NodeHealth {
        guard isRunning else { return .stopped }
        if activeShards > 0 { return .active }
        if let frameLastAdvancedAt,
            frame > 0,
            Date().timeIntervalSince(frameLastAdvancedAt) >= 5 * 60
        {
            return .stalled
        }
        if pendingJoins > 0 { return .joining }
        return .syncing
    }

    public var isLogFresh: Bool {
        isLogFresh(at: Date())
    }

    public func isLogFresh(at now: Date) -> Bool {
        guard let logLastModifiedAt else { return false }
        return now.timeIntervalSince(logLastModifiedAt) < 90
    }
}
