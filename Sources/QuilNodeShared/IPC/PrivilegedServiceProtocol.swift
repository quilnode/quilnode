import Foundation

/// The versioned, local-only protocol shared by the unprivileged app and the
/// authenticated root service. Keeping the wire contract in this lowest-level
/// module prevents the two processes from silently drifting apart.
public enum PrivilegedServiceProtocol {
    public static let version = 1
    public static let currentServiceBuild = 114
    public static let minimumSupportedServiceBuild = 114
    public static let maximumRequestBytes = 64_000
    public static let maximumResponseBytes = 1_000_000
}

/// Stable stages for daemon-owned work. The app can disappear and reconnect
/// without guessing progress from human-readable status text.
public enum PrivilegedOperationStage: String, Codable, Equatable, Sendable {
    case accepted
    case waitingForExclusiveAccess
    case validatingPlan
    case verifyingArtifact
    case installingFiles
    case verifyingInstalledArtifact
    case probingRuntime
    case recordingProvenance
    case activatingRuntime
    case validatingHealth
    case completed
}

public enum PrivilegedServiceAction: String, CaseIterable, Codable, Sendable {
    case capabilities
    case upgradeService
    case status
    case nodeInfo
    case metrics
    case balance
    case proverTelemetry
    case start
    case stop
    case restart
    case install
    case activate
    case rollback
    case operationStatus
    case walletInventory
    case walletInspect
    case walletTransact
    case firewallStatus
    case firewallConfigure
    case qclientStatus
    case qclientInstall
    case nodeUpdatePolicyStatus
    case nodeUpdatePolicyConfigure
}

/// Bounded output from two fixed, read-only qclient commands. The privileged
/// service owns command selection and never accepts caller-provided arguments,
/// while the app remains responsible for parsing operator-facing telemetry.
public struct QClientProverTelemetryPayload: Codable, Equatable, Sendable {
    public var statusOutput: String
    public var shardInfoOutput: String
    public var observedAt: Date

    public init(statusOutput: String, shardInfoOutput: String, observedAt: Date) {
        self.statusOutput = statusOutput
        self.shardInfoOutput = shardInfoOutput
        self.observedAt = observedAt
    }
}

public struct PrivilegedServiceRequest: Codable, Sendable {
    public var protocolVersion = PrivilegedServiceProtocol.version
    public var action: PrivilegedServiceAction
    public var manifestPath: String?
    public var operationID: String?
    public var nodeUpdatePolicy: AutomaticNodeUpdatePolicy?

    public init(
        action: PrivilegedServiceAction,
        manifestPath: String? = nil,
        operationID: String? = nil,
        nodeUpdatePolicy: AutomaticNodeUpdatePolicy? = nil
    ) {
        self.action = action
        self.manifestPath = manifestPath
        self.operationID = operationID
        self.nodeUpdatePolicy = nodeUpdatePolicy
    }
}

public struct PrivilegedServiceResponse: Codable, Sendable {
    public var protocolVersion = PrivilegedServiceProtocol.version
    public var success: Bool
    public var message: String
    public var serviceUser: String?
    public var nodePID: Int32?
    public var nodeInfoOutput: String?
    public var peerInfoOutput: String?
    public var metricsOutput: String?
    public var balanceOutput: String?
    public var walletOutput: String?
    public var firewallOutput: String?
    public var qclientOutput: String?
    public var operationID: String?
    public var operationState: String?
    public var operationStage: PrivilegedOperationStage?
    public var serviceBuild: Int?
    /// Set only when the authenticated service deliberately refuses a
    /// passwordless high-risk operation and requires fresh macOS user presence.
    public var authorizationRequired: Bool?
    public var nodeUpdatePolicy: AutomaticNodeUpdatePolicy?

    public init(
        success: Bool,
        message: String,
        serviceUser: String? = "_quilnode",
        nodePID: Int32? = nil,
        nodeInfoOutput: String? = nil,
        peerInfoOutput: String? = nil,
        metricsOutput: String? = nil,
        balanceOutput: String? = nil,
        walletOutput: String? = nil,
        firewallOutput: String? = nil,
        qclientOutput: String? = nil,
        operationID: String? = nil,
        operationState: String? = nil,
        operationStage: PrivilegedOperationStage? = nil,
        serviceBuild: Int? = nil,
        authorizationRequired: Bool? = nil,
        nodeUpdatePolicy: AutomaticNodeUpdatePolicy? = nil
    ) {
        self.success = success
        self.message = message
        self.serviceUser = serviceUser
        self.nodePID = nodePID
        self.nodeInfoOutput = nodeInfoOutput
        self.peerInfoOutput = peerInfoOutput
        self.metricsOutput = metricsOutput
        self.balanceOutput = balanceOutput
        self.walletOutput = walletOutput
        self.firewallOutput = firewallOutput
        self.qclientOutput = qclientOutput
        self.operationID = operationID
        self.operationState = operationState
        self.operationStage = operationStage
        self.serviceBuild = serviceBuild
        self.authorizationRequired = authorizationRequired
        self.nodeUpdatePolicy = nodeUpdatePolicy
    }
}
