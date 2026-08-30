import Foundation

/// A deliberately small, append-only observation used to explain what the
/// local node did over time. It contains no key material, addresses, ports, or
/// raw log lines and is therefore safe to persist in QuilNode's private app
/// support directory.
public struct NodeActivitySample: Codable, Equatable, Identifiable, Sendable {
    public var timestamp: Date
    public var frame: UInt64
    public var peers: Int
    public var pendingJoins: Int
    public var activeShards: Int
    public var totalAllocations: Int
    public var isRunning: Bool
    public var seniority: Int64?
    public var inboundConnections: UInt64?
    public var framesReceived: UInt64?
    public var routerDrops: UInt64?
    public var lastRewardCreditFrame: UInt64?
    public var version: String?
    public var chainProgressState: ChainProgressState?

    public var id: Date { timestamp }

    public init(
        timestamp: Date,
        frame: UInt64,
        peers: Int,
        pendingJoins: Int,
        activeShards: Int,
        totalAllocations: Int,
        isRunning: Bool,
        seniority: Int64? = nil,
        inboundConnections: UInt64? = nil,
        framesReceived: UInt64? = nil,
        routerDrops: UInt64? = nil,
        lastRewardCreditFrame: UInt64? = nil,
        version: String? = nil,
        chainProgressState: ChainProgressState? = nil
    ) {
        self.timestamp = timestamp
        self.frame = frame
        self.peers = peers
        self.pendingJoins = pendingJoins
        self.activeShards = activeShards
        self.totalAllocations = totalAllocations
        self.isRunning = isRunning
        self.seniority = seniority
        self.inboundConnections = inboundConnections
        self.framesReceived = framesReceived
        self.routerDrops = routerDrops
        self.lastRewardCreditFrame = lastRewardCreditFrame
        self.version = version
        self.chainProgressState = chainProgressState
    }
}

public enum NodeActivityCategory: String, CaseIterable, Codable, Sendable {
    case runtime
    case proving
    case network
    case rewards
    case identity
}

public enum NodeActivityEventKind: String, Codable, Hashable, Sendable {
    case nodeStarted
    case nodeStopped
    case versionChanged
    case allocationChanged
    case pendingJoinChanged
    case activeShardChanged
    case peerMeshChanged
    case inboundObserved
    case seniorityChanged
    case rewardCredited
    case routerDropsIncreased
    case archiveRecoveryStarted
    case archiveRecoveryEnded
}

public struct NodeActivityEvent: Equatable, Identifiable, Sendable {
    public var id: String
    public var timestamp: Date
    public var category: NodeActivityCategory
    public var kind: NodeActivityEventKind
    public var title: String
    public var detail: String
    public var sensitiveValue: String?

    public init(
        id: String,
        timestamp: Date,
        category: NodeActivityCategory,
        kind: NodeActivityEventKind,
        title: String,
        detail: String,
        sensitiveValue: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.kind = kind
        self.title = title
        self.detail = detail
        self.sensitiveValue = sensitiveValue
    }
}

public struct NodeActivitySummary: Equatable, Sendable {
    public var duration: TimeInterval
    public var frameDelta: UInt64
    public var averageFramesPerMinute: Double?
    public var peerMinimum: Int?
    public var peerMaximum: Int?
    public var peerDelta: Int
    public var continuity: Double?
    public var lifecycleChanges: Int
    public var eventCount: Int

    public init(
        duration: TimeInterval = 0,
        frameDelta: UInt64 = 0,
        averageFramesPerMinute: Double? = nil,
        peerMinimum: Int? = nil,
        peerMaximum: Int? = nil,
        peerDelta: Int = 0,
        continuity: Double? = nil,
        lifecycleChanges: Int = 0,
        eventCount: Int = 0
    ) {
        self.duration = duration
        self.frameDelta = frameDelta
        self.averageFramesPerMinute = averageFramesPerMinute
        self.peerMinimum = peerMinimum
        self.peerMaximum = peerMaximum
        self.peerDelta = peerDelta
        self.continuity = continuity
        self.lifecycleChanges = lifecycleChanges
        self.eventCount = eventCount
    }
}
