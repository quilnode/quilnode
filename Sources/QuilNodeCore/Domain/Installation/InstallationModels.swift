import Foundation

public enum InstallationCheckState: String, Codable, Sendable {
    case pass, warning, blocked, notRequired
}

public struct InstallationCheck: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var detail: String
    public var state: InstallationCheckState

    public init(id: String, title: String, detail: String, state: InstallationCheckState) {
        self.id = id
        self.title = title
        self.detail = detail
        self.state = state
    }
}

public struct InstallationPreflight: Codable, Sendable {
    public var checkedAt: Date
    public var hardware: [InstallationCheck]
    public var productionRequirements: [InstallationCheck]
    public var sourceToolchain: [InstallationCheck]
    public var nodeInstalled: Bool
    public var secureServiceReady: Bool
    public var secureServiceBuild: Int?
    public var qclientStatus: ManagedQClientStatus?
    public var qclientCompatibleWithNode: Bool
    public var installedNodeBuild: InstalledNodeBuild?

    public init(
        checkedAt: Date = Date(),
        hardware: [InstallationCheck],
        productionRequirements: [InstallationCheck],
        sourceToolchain: [InstallationCheck],
        nodeInstalled: Bool,
        secureServiceReady: Bool,
        secureServiceBuild: Int? = nil,
        qclientStatus: ManagedQClientStatus? = nil,
        qclientCompatibleWithNode: Bool = false,
        installedNodeBuild: InstalledNodeBuild? = nil
    ) {
        self.checkedAt = checkedAt
        self.hardware = hardware
        self.productionRequirements = productionRequirements
        self.sourceToolchain = sourceToolchain
        self.nodeInstalled = nodeInstalled
        self.secureServiceReady = secureServiceReady
        self.secureServiceBuild = secureServiceBuild
        self.qclientStatus = qclientStatus
        self.qclientCompatibleWithNode = qclientCompatibleWithNode
        self.installedNodeBuild = installedNodeBuild
    }

    public var productionReady: Bool {
        !(hardware + productionRequirements).contains { $0.state == .blocked }
    }
}

public enum FirstInstallPhase: String, Codable, Sendable {
    case inspecting
    case ready
    case downloading
    case verifying
    case awaitingAuthorization
    case authorizing
    case installing
    case validating
    case complete
    case failed
}
