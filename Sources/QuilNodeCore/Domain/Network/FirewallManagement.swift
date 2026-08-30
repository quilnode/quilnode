import Foundation

/// The macOS Application Firewall state that QuilNode can prove locally.
/// Private paths and firewall internals stay behind the privileged service;
/// the dashboard receives only the minimum state needed to guide the operator.
public struct ManagedFirewallStatus: Codable, Equatable, Sendable {
    public enum NodeRule: String, Codable, Sendable {
        case missing
        case allowed
        case blocked
        case unavailable
    }

    public var globalEnabled: Bool
    public var blockAllEnabled: Bool
    public var stealthEnabled: Bool
    public var nodeRule: NodeRule
    public var managedByQuilNode: Bool
    public var verifiedAt: Date

    public init(
        globalEnabled: Bool,
        blockAllEnabled: Bool,
        stealthEnabled: Bool,
        nodeRule: NodeRule,
        managedByQuilNode: Bool,
        verifiedAt: Date = Date()
    ) {
        self.globalEnabled = globalEnabled
        self.blockAllEnabled = blockAllEnabled
        self.stealthEnabled = stealthEnabled
        self.nodeRule = nodeRule
        self.managedByQuilNode = managedByQuilNode
        self.verifiedAt = verifiedAt
    }

    public var isReady: Bool {
        globalEnabled && !blockAllEnabled && nodeRule == .allowed
    }

    public static let unavailable = ManagedFirewallStatus(
        globalEnabled: false,
        blockAllEnabled: false,
        stealthEnabled: false,
        nodeRule: .unavailable,
        managedByQuilNode: false
    )
}
