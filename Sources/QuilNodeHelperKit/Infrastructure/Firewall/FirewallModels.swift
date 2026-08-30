import Foundation

struct FirewallStatusPayload: Codable {
    enum NodeRule: String, Codable { case missing, allowed, blocked, unavailable }

    var globalEnabled: Bool
    var blockAllEnabled: Bool
    var stealthEnabled: Bool
    var nodeRule: NodeRule
    var managedByQuilNode: Bool
    var verifiedAt: Date
}

struct ManagedFirewallRecord: Codable {
    var schemaVersion = 1
    var nodeBinaryPath: String
    var firewallWasEnabledBeforeManagement: Bool
    var managedAt: Date
    var lastVerifiedAt: Date
}
