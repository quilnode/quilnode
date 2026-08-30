import Foundation

public enum GatewayRouteKind: String, Codable, Equatable, Sendable {
    case privateLAN
    case localManaged
    case tunnel
    case publicAddress
    case unavailable
}

public struct GatewayRouteAssessment: Codable, Equatable, Sendable {
    public var kind: GatewayRouteKind
    public var address: String?
    public var interfaceName: String?
    public var interfaceDisplayName: String?
    public var isSafeBrowserTarget: Bool
    public var title: String
    public var detail: String

    public init(
        kind: GatewayRouteKind,
        address: String?,
        interfaceName: String?,
        interfaceDisplayName: String?,
        isSafeBrowserTarget: Bool,
        title: String,
        detail: String
    ) {
        self.kind = kind
        self.address = address
        self.interfaceName = interfaceName
        self.interfaceDisplayName = interfaceDisplayName
        self.isSafeBrowserTarget = isSafeBrowserTarget
        self.title = title
        self.detail = detail
    }

    public var signature: String {
        [kind.rawValue, address ?? "", interfaceName ?? ""].joined(separator: "|")
    }
}

/// Classifies the active macOS default route without claiming that the next
/// hop is a specific router model or that it necessarily hosts an admin page.
/// Only local address classes are eligible for automatic browser suggestions.
public enum GatewayRouteClassifier {
    public static func assess(_ inspection: NetworkLocalInspection) -> GatewayRouteAssessment {
        let interfaceName = inspection.interfaceName
        let displayName = inspection.interfaceDisplayName
        guard let address = inspection.gatewayIPv4,
            !address.isEmpty,
            let octets = ipv4Octets(address)
        else {
            return .init(
                kind: .unavailable,
                address: inspection.gatewayIPv4,
                interfaceName: interfaceName,
                interfaceDisplayName: displayName,
                isSafeBrowserTarget: false,
                title: "No IPv4 gateway detected",
                detail: "Open macOS Network settings or use the router manufacturer's app or documentation."
            )
        }

        if isTunnelInterface(interfaceName) {
            return .init(
                kind: .tunnel,
                address: address,
                interfaceName: interfaceName,
                interfaceDisplayName: displayName,
                isSafeBrowserTarget: false,
                title: "Tunnel gateway detected",
                detail: "A VPN or tunnel owns the default route, so QuilNode will not present it as your home router."
            )
        }

        if isRFC1918(octets) {
            return .init(
                kind: .privateLAN,
                address: address,
                interfaceName: interfaceName,
                interfaceDisplayName: displayName,
                isSafeBrowserTarget: true,
                title: "Private LAN gateway",
                detail:
                    "macOS sends internet traffic through this local address. On a typical home network it is the router, but the manufacturer may use an app or another management address."
            )
        }

        if isLinkLocal(octets) || isCarrierGradeNAT(octets) {
            return .init(
                kind: .localManaged,
                address: address,
                interfaceName: interfaceName,
                interfaceDisplayName: displayName,
                isSafeBrowserTarget: true,
                title: "Locally reachable gateway",
                detail:
                    "The address is local to this network, but it may belong to a modem, mesh hop, or provider-managed gateway rather than the router you administer."
            )
        }

        return .init(
            kind: .publicAddress,
            address: address,
            interfaceName: interfaceName,
            interfaceDisplayName: displayName,
            isSafeBrowserTarget: false,
            title: "Managed or public gateway",
            detail:
                "This default route is not a private local address, so QuilNode will not open it automatically. Use the network administrator or router manufacturer's instructions."
        )
    }

    public static func isTunnelInterface(_ name: String?) -> Bool {
        guard let name = name?.lowercased() else { return false }
        return ["utun", "tun", "tap", "ppp", "ipsec", "gif", "stf"].contains { name.hasPrefix($0) }
    }

    public static func isRFC1918(_ address: String) -> Bool {
        ipv4Octets(address).map(isRFC1918) ?? false
    }

    private static func ipv4Octets(_ address: String) -> [UInt8]? {
        let components = address.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 4 else { return nil }
        let octets = components.compactMap { UInt8($0) }
        return octets.count == 4 ? octets : nil
    }

    private static func isRFC1918(_ octets: [UInt8]) -> Bool {
        octets[0] == 10
            || (octets[0] == 172 && (16...31).contains(octets[1]))
            || (octets[0] == 192 && octets[1] == 168)
    }

    private static func isLinkLocal(_ octets: [UInt8]) -> Bool {
        octets[0] == 169 && octets[1] == 254
    }

    private static func isCarrierGradeNAT(_ octets: [UInt8]) -> Bool {
        octets[0] == 100 && (64...127).contains(octets[1])
    }
}
