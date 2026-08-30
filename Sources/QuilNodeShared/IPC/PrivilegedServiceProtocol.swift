import Foundation

/// The versioned, local-only protocol shared by the unprivileged app and the
/// authenticated root service. Keeping the wire contract in this lowest-level
/// module prevents the two processes from silently drifting apart.
public enum PrivilegedServiceProtocol {
    public static let version = 1
    public static let currentServiceBuild = 109
    public static let minimumSupportedServiceBuild = 109
    public static let maximumRequestBytes = 64_000
    public static let maximumResponseBytes = 1_000_000
}

public enum PrivilegedServiceAction: String, CaseIterable, Codable, Sendable {
    case capabilities
    case upgradeService
    case status
    case nodeInfo
    case metrics
    case balance
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
}

public struct PrivilegedServiceRequest: Codable, Sendable {
    public var protocolVersion = PrivilegedServiceProtocol.version
    public var action: PrivilegedServiceAction
    public var manifestPath: String?
    public var operationID: String?

    public init(
        action: PrivilegedServiceAction,
        manifestPath: String? = nil,
        operationID: String? = nil
    ) {
        self.action = action
        self.manifestPath = manifestPath
        self.operationID = operationID
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
    public var serviceBuild: Int?
    /// Set only when the authenticated service deliberately refuses a
    /// passwordless high-risk operation and requires fresh macOS user presence.
    public var authorizationRequired: Bool?

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
        serviceBuild: Int? = nil,
        authorizationRequired: Bool? = nil
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
        self.serviceBuild = serviceBuild
        self.authorizationRequired = authorizationRequired
    }
}
