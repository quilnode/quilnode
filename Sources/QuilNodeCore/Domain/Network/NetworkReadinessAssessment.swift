import Foundation

public enum NetworkReadinessState: String, Codable, Equatable, Sendable {
    case offline
    case inspecting
    case localConfigurationIssue
    case waitingForEvidence
    case reviewRouter
    case inboundVerified
}

public struct NetworkReadinessAssessment: Codable, Equatable, Sendable {
    public var state: NetworkReadinessState
    public var title: String
    public var detail: String
    public var missingMasterPorts: [UInt16]

    public init(
        state: NetworkReadinessState,
        title: String,
        detail: String,
        missingMasterPorts: [UInt16] = []
    ) {
        self.state = state
        self.title = title
        self.detail = detail
        self.missingMasterPorts = missingMasterPorts
    }
}

public enum NetworkReadinessEvaluator {
    public static let routerReviewGracePeriod: TimeInterval = 30 * 60

    public static func evaluate(
        node: NodeSnapshot,
        inspection: NetworkLocalInspection,
        portPlan: NetworkPortPlan = .residentialTCP(localWorkerCount: nil)
    ) -> NetworkReadinessAssessment {
        guard node.isRunning else {
            return .init(
                state: .offline,
                title: "Node is offline",
                detail: "Start the node before checking inbound connectivity."
            )
        }
        guard inspection.inspectionSucceeded else {
            return .init(
                state: .inspecting,
                title: "Inspecting this Mac",
                detail: "QuilNode is checking local listeners, the active network, and macOS Firewall."
            )
        }

        let missing = portPlan.required
            .filter { !inspection.isListening(for: $0) }
            .flatMap { Array($0.startPort...$0.endPort) }
            .sorted()
        if !missing.isEmpty {
            return .init(
                state: .localConfigurationIssue,
                title: "Local listener needs attention",
                detail:
                    "The node is not listening on every required master port. Fix the local node before changing the router.",
                missingMasterPorts: missing
            )
        }

        if (node.inboundConnectionsEstablished ?? 0) > 0 || inspection.inboundPeerSockets > 0 {
            return .init(
                state: .inboundVerified,
                title: "Inbound peer traffic verified",
                detail:
                    "Local node metrics or macOS socket state confirm that remote peers have established inbound connections to this process."
            )
        }

        let uptime = NodeProcessUptimeParser.seconds(from: node.processUptime)
        if let uptime, uptime >= routerReviewGracePeriod {
            return .init(
                state: .reviewRouter,
                title: "Review router forwarding",
                detail:
                    "The node has listened locally for at least 30 minutes without recording an inbound connection. This is a prompt to check the router, not proof that it is blocked."
            )
        }

        return .init(
            state: .waitingForEvidence,
            title: "Waiting for inbound evidence",
            detail:
                "The node is listening correctly. QuilNode will confirm reachability when the node itself records an inbound peer connection."
        )
    }
}
