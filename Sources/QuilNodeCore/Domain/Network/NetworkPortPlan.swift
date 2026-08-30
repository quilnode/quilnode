import Foundation

public enum NetworkTransport: String, Codable, CaseIterable, Sendable {
    case tcp = "TCP"
    case udp = "UDP"
    case tcpAndUDP = "TCP + UDP"
}

public enum NetworkPortProfileKind: String, Codable, Equatable, Sendable {
    case recommendedResidential
    case custom
}

/// The small, non-secret networking contract QuilNode is allowed to retain.
/// It intentionally contains no addresses, identity material, or node config.
public struct NetworkPortProfile: Codable, Equatable, Sendable {
    public var kind: NetworkPortProfileKind
    public var peerPort: UInt16
    public var peerTransport: NetworkTransport
    public var streamPort: UInt16

    public init(
        kind: NetworkPortProfileKind,
        peerPort: UInt16,
        peerTransport: NetworkTransport,
        streamPort: UInt16
    ) {
        self.kind = kind
        self.peerPort = peerPort
        self.peerTransport = peerTransport
        self.streamPort = streamPort
    }

    public static let recommendedResidential = NetworkPortProfile(
        kind: .recommendedResidential,
        peerPort: 8_336,
        peerTransport: .tcp,
        streamPort: 8_340
    )

    public var title: String {
        switch kind {
        case .recommendedResidential: "Recommended residential"
        case .custom: "Custom verified"
        }
    }
}

public struct NetworkPortProfileValidation: Equatable, Sendable {
    public var issues: [String]
    public var inactiveRequirements: [NetworkPortRequirement]

    public init(issues: [String] = [], inactiveRequirements: [NetworkPortRequirement] = []) {
        self.issues = issues
        self.inactiveRequirements = inactiveRequirements
    }

    public var isStructurallyValid: Bool { issues.isEmpty }
    public var isReadyToActivate: Bool { issues.isEmpty && inactiveRequirements.isEmpty }
}

public struct NetworkPortRequirement: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var startPort: UInt16
    public var endPort: UInt16
    public var transport: NetworkTransport
    public var purpose: String
    public var requiredForCurrentRuntime: Bool

    public init(
        id: String,
        title: String,
        startPort: UInt16,
        endPort: UInt16? = nil,
        transport: NetworkTransport,
        purpose: String,
        requiredForCurrentRuntime: Bool
    ) {
        self.id = id
        self.title = title
        self.startPort = startPort
        self.endPort = endPort ?? startPort
        self.transport = transport
        self.purpose = purpose
        self.requiredForCurrentRuntime = requiredForCurrentRuntime
    }

    public var portLabel: String {
        startPort == endPort ? String(startPort) : "\(startPort)–\(endPort)"
    }
}

public struct NetworkPortPlan: Equatable, Sendable {
    public var profile: NetworkPortProfile
    public var required: [NetworkPortRequirement]
    public var clusterOnly: [NetworkPortRequirement]

    public init(
        profile: NetworkPortProfile,
        required: [NetworkPortRequirement],
        clusterOnly: [NetworkPortRequirement]
    ) {
        self.profile = profile
        self.required = required
        self.clusterOnly = clusterOnly
    }

    /// The official residential recommendation uses TCP for the master
    /// listener. `.25` local thread workers stay inside the process and do not
    /// need the historical worker ranges. Those ranges remain available for
    /// explicit external/cluster worker deployments.
    public static func residentialTCP(localWorkerCount: Int?) -> NetworkPortPlan {
        plan(for: .recommendedResidential, localWorkerCount: localWorkerCount)
    }

    public static func plan(
        for profile: NetworkPortProfile,
        localWorkerCount: Int?
    ) -> NetworkPortPlan {
        let workerCount = max(localWorkerCount ?? 1, 1)
        let p2pEnd = UInt16(min(25_000 + workerCount - 1, Int(UInt16.max)))
        let streamEnd = UInt16(min(32_500 + workerCount - 1, Int(UInt16.max)))
        return NetworkPortPlan(
            profile: profile,
            required: [
                NetworkPortRequirement(
                    id: "master-p2p",
                    title: "Master peer traffic",
                    startPort: profile.peerPort,
                    transport: profile.peerTransport,
                    purpose: "Receives Quilibrium peer connections",
                    requiredForCurrentRuntime: true
                ),
                NetworkPortRequirement(
                    id: "master-stream",
                    title: "Master streaming",
                    startPort: profile.streamPort,
                    transport: .tcp,
                    purpose: "Serves protocol streams to peers",
                    requiredForCurrentRuntime: true
                ),
            ],
            clusterOnly: [
                NetworkPortRequirement(
                    id: "worker-p2p",
                    title: "External worker peer traffic",
                    startPort: 25_000,
                    endPort: p2pEnd,
                    transport: .tcpAndUDP,
                    purpose: "Only for separate worker processes or machines",
                    requiredForCurrentRuntime: false
                ),
                NetworkPortRequirement(
                    id: "worker-stream",
                    title: "External worker streaming",
                    startPort: 32_500,
                    endPort: streamEnd,
                    transport: .tcp,
                    purpose: "Only for separate worker processes or machines",
                    requiredForCurrentRuntime: false
                ),
            ]
        )
    }

    public func validation(in inspection: NetworkLocalInspection) -> NetworkPortProfileValidation {
        var issues: [String] = []
        if profile.peerPort < 1_024 || profile.streamPort < 1_024 {
            issues.append("Use ports from 1024 through 65535.")
        }
        if profile.peerPort == profile.streamPort {
            issues.append("Peer traffic and streaming need different ports.")
        }
        if profile.peerTransport == .tcpAndUDP {
            issues.append("Choose one active peer transport: TCP or UDP/QUIC.")
        }

        let inactive = issues.isEmpty ? required.filter { !inspection.isListening(for: $0) } : []
        return NetworkPortProfileValidation(issues: issues, inactiveRequirements: inactive)
    }
}
