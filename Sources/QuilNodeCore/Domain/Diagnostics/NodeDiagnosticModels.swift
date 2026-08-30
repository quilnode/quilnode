import Foundation

public enum NodeDiagnosticCategory: String, CaseIterable, Codable, Sendable {
    case runtime
    case progress
    case network
    case tooling
}

public enum NodeDiagnosticState: String, Codable, Sendable {
    case checking
    case passed
    /// Healthy local operation that is intentionally waiting on shared state.
    case waiting
    case advisory
    case failed

    public var rank: Int {
        switch self {
        case .checking: 0
        case .passed: 1
        case .waiting: 2
        case .advisory: 3
        case .failed: 4
        }
    }
}

public enum NodeDiagnosticRepair: String, Codable, Identifiable, Sendable {
    case refreshEvidence
    case startNode
    case restartNode
    case openNetwork
    case configureFirewall
    case openUpdates
    case repairQClient

    public var id: String { rawValue }
}

public struct NodeDiagnosticCheck: Equatable, Identifiable, Sendable {
    public var id: String
    public var category: NodeDiagnosticCategory
    public var state: NodeDiagnosticState
    public var title: String
    public var summary: String
    public var evidence: String
    public var observedAt: Date?
    public var repair: NodeDiagnosticRepair?

    public init(
        id: String,
        category: NodeDiagnosticCategory,
        state: NodeDiagnosticState,
        title: String,
        summary: String,
        evidence: String,
        observedAt: Date? = nil,
        repair: NodeDiagnosticRepair? = nil
    ) {
        self.id = id
        self.category = category
        self.state = state
        self.title = title
        self.summary = summary
        self.evidence = evidence
        self.observedAt = observedAt
        self.repair = repair
    }
}

public struct NodeDiagnosticReport: Equatable, Sendable {
    public var generatedAt: Date
    public var checks: [NodeDiagnosticCheck]

    public init(generatedAt: Date, checks: [NodeDiagnosticCheck]) {
        self.generatedAt = generatedAt
        self.checks = checks
    }

    public var overallState: NodeDiagnosticState {
        if checks.contains(where: { $0.state == .failed }) { return .failed }
        if checks.contains(where: { $0.state == .advisory }) { return .advisory }
        if checks.contains(where: { $0.state == .waiting }) { return .waiting }
        if checks.contains(where: { $0.state == .checking }) { return .checking }
        return .passed
    }

    public var passedCount: Int { checks.filter { $0.state == .passed }.count }
    public var waitingCount: Int { checks.filter { $0.state == .waiting }.count }
    public var actionCount: Int { checks.filter { $0.state == .failed || $0.state == .advisory }.count }
}

public struct NodeDiagnosticContext: Sendable {
    public var snapshot: NodeSnapshot
    public var initialRefreshComplete: Bool
    public var serviceAvailable: Bool?
    public var networkAssessment: NetworkReadinessAssessment
    public var networkInspection: NetworkLocalInspection
    public var firewall: ManagedFirewallStatus?
    public var qclientReady: Bool?
    public var qclientCompatible: Bool?
    public var now: Date

    public init(
        snapshot: NodeSnapshot,
        initialRefreshComplete: Bool,
        serviceAvailable: Bool?,
        networkAssessment: NetworkReadinessAssessment,
        networkInspection: NetworkLocalInspection,
        firewall: ManagedFirewallStatus?,
        qclientReady: Bool?,
        qclientCompatible: Bool?,
        now: Date = Date()
    ) {
        self.snapshot = snapshot
        self.initialRefreshComplete = initialRefreshComplete
        self.serviceAvailable = serviceAvailable
        self.networkAssessment = networkAssessment
        self.networkInspection = networkInspection
        self.firewall = firewall
        self.qclientReady = qclientReady
        self.qclientCompatible = qclientCompatible
        self.now = now
    }
}
