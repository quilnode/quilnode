import Foundation

public enum NetworkFirewallState: String, Codable, Equatable, Sendable {
    case disabled
    case enabled
    case blockingAll
    case unknown
}

public struct NetworkLocalInspection: Codable, Equatable, Sendable {
    public var observedAt: Date
    public var localIPv4: String?
    public var gatewayIPv4: String?
    public var interfaceName: String?
    public var interfaceDisplayName: String?
    public var firewallState: NetworkFirewallState
    public var tcpListeners: Set<UInt16>
    public var udpListeners: Set<UInt16>
    public var inboundPeerSockets: Int
    public var inspectionSucceeded: Bool

    public init(
        observedAt: Date = Date(),
        localIPv4: String? = nil,
        gatewayIPv4: String? = nil,
        interfaceName: String? = nil,
        interfaceDisplayName: String? = nil,
        firewallState: NetworkFirewallState = .unknown,
        tcpListeners: Set<UInt16> = [],
        udpListeners: Set<UInt16> = [],
        inboundPeerSockets: Int = 0,
        inspectionSucceeded: Bool = false
    ) {
        self.observedAt = observedAt
        self.localIPv4 = localIPv4
        self.gatewayIPv4 = gatewayIPv4
        self.interfaceName = interfaceName
        self.interfaceDisplayName = interfaceDisplayName
        self.firewallState = firewallState
        self.tcpListeners = tcpListeners
        self.udpListeners = udpListeners
        self.inboundPeerSockets = inboundPeerSockets
        self.inspectionSucceeded = inspectionSucceeded
    }

    public static let empty = NetworkLocalInspection()

    public func isListening(for requirement: NetworkPortRequirement) -> Bool {
        let ports = Set(requirement.startPort...requirement.endPort)
        switch requirement.transport {
        case .tcp:
            return ports.isSubset(of: tcpListeners)
        case .udp:
            return ports.isSubset(of: udpListeners)
        case .tcpAndUDP:
            return ports.isSubset(of: tcpListeners) && ports.isSubset(of: udpListeners)
        }
    }
}
