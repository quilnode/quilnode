import Foundation

public struct ShardAllocation: Codable, Equatable, Sendable, Identifiable {
    public var index: Int
    public var filter: String
    public var status: String
    public var worker: String?
    public var action: String?
    public var joinFrame: UInt64?
    public var confirmFrame: UInt64?
    public var lastActiveFrame: UInt64?

    public var id: Int { index }

    public init(
        index: Int,
        filter: String,
        status: String,
        worker: String? = nil,
        action: String? = nil,
        joinFrame: UInt64? = nil,
        confirmFrame: UInt64? = nil,
        lastActiveFrame: UInt64? = nil
    ) {
        self.index = index
        self.filter = filter
        self.status = status
        self.worker = worker
        self.action = action
        self.joinFrame = joinFrame
        self.confirmFrame = confirmFrame
        self.lastActiveFrame = lastActiveFrame
    }
}

public struct LocalProverStatus: Equatable, Sendable {
    public var seniority: Int64
    public var peerScore: Double?
    public var runningWorkers: Int
    public var allocatedWorkers: Int
    public var lastReceivedFrame: UInt64
    public var lastGlobalHeadFrame: UInt64
    public var epoch: UInt64
    public var epochLength: UInt64
    public var nextEpochFrame: UInt64
    public var reachable: Bool?
    public var allocations: [ShardAllocation]

    public init(
        seniority: Int64 = 0,
        peerScore: Double? = nil,
        runningWorkers: Int = 0,
        allocatedWorkers: Int = 0,
        lastReceivedFrame: UInt64 = 0,
        lastGlobalHeadFrame: UInt64 = 0,
        epoch: UInt64 = 0,
        epochLength: UInt64 = 720,
        nextEpochFrame: UInt64 = 0,
        reachable: Bool? = nil,
        allocations: [ShardAllocation] = []
    ) {
        self.seniority = seniority
        self.peerScore = peerScore
        self.runningWorkers = runningWorkers
        self.allocatedWorkers = allocatedWorkers
        self.lastReceivedFrame = lastReceivedFrame
        self.lastGlobalHeadFrame = lastGlobalHeadFrame
        self.epoch = epoch
        self.epochLength = epochLength
        self.nextEpochFrame = nextEpochFrame
        self.reachable = reachable
        self.allocations = allocations
    }
}

public struct QuilBalance: Equatable, Sendable {
    public var amount: String
    public var account: String

    public init(amount: String, account: String) {
        self.amount = amount
        self.account = account
    }
}

public struct NodeInfo: Equatable, Sendable {
    public var peerID: String?
    public var legacyPeerID: String?
    public var proverAddress: String?
    public var version: String?
    public var seniority: Int64
    public var runningWorkers: Int
    public var activeWorkers: Int
    public var frame: UInt64

    public init(
        peerID: String? = nil,
        legacyPeerID: String? = nil,
        proverAddress: String? = nil,
        version: String? = nil,
        seniority: Int64 = 0,
        runningWorkers: Int = 0,
        activeWorkers: Int = 0,
        frame: UInt64 = 0
    ) {
        self.peerID = peerID
        self.legacyPeerID = legacyPeerID
        self.proverAddress = proverAddress
        self.version = version
        self.seniority = seniority
        self.runningWorkers = runningWorkers
        self.activeWorkers = activeWorkers
        self.frame = frame
    }
}

public struct CollectionResult: Sendable {
    public var snapshot: NodeSnapshot
    public var nodeInfo: NodeInfo?

    public init(snapshot: NodeSnapshot, nodeInfo: NodeInfo?) {
        self.snapshot = snapshot
        self.nodeInfo = nodeInfo
    }
}

public struct BalanceCollectionResult: Sendable {
    public var balance: QuilBalance?
    public var error: String?

    public init(balance: QuilBalance? = nil, error: String? = nil) {
        self.balance = balance
        self.error = error
    }
}

public struct ProverStatusCollectionResult: Sendable {
    public var status: LocalProverStatus?
    public var error: String?

    public init(status: LocalProverStatus? = nil, error: String? = nil) {
        self.status = status
        self.error = error
    }
}

public struct LocalRegistryEvidence: Equatable, Sendable {
    public var proverAddress: String?
    public var seniority: Int64
    public var previousSeniority: Int64?
    public var allocations: Int
    public var status: String?
    public var observedAt: Date?
    public var kind: SeniorityEvidenceKind

    public init(
        proverAddress: String? = nil,
        seniority: Int64 = 0,
        previousSeniority: Int64? = nil,
        allocations: Int = 0,
        status: String? = nil,
        observedAt: Date? = nil,
        kind: SeniorityEvidenceKind = .registrySnapshot
    ) {
        self.proverAddress = proverAddress
        self.seniority = seniority
        self.previousSeniority = previousSeniority
        self.allocations = allocations
        self.status = status
        self.observedAt = observedAt
        self.kind = kind
    }
}
