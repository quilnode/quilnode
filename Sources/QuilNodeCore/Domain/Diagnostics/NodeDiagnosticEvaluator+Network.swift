import Foundation

extension NodeDiagnosticEvaluator {
    static func peerCheck(_ context: NodeDiagnosticContext, uptime: TimeInterval?) -> NodeDiagnosticCheck {
        let snapshot = context.snapshot
        guard context.initialRefreshComplete, snapshot.isRunning else {
            return check(
                id: "peer-mesh", category: .network, state: .checking,
                title: "Peer mesh", summary: "Peer readiness has not been established.",
                evidence: snapshot.isRunning ? "Waiting for peer telemetry." : "The node must be running."
            )
        }
        if snapshot.peers > 0 {
            return check(
                id: "peer-mesh", category: .network, state: .passed,
                title: "Peer mesh", summary: "The node has live peer connections.",
                evidence: "\(snapshot.peers) peers reported by the local node.", observedAt: snapshot.metricsUpdatedAt
            )
        }
        let warming = (uptime ?? 0) < 180
        return check(
            id: "peer-mesh", category: .network, state: warming ? .checking : .failed,
            title: "Peer mesh",
            summary: warming ? "Waiting for initial peers." : "No peers are connected.",
            evidence: "The local peer count is zero.", repair: warming ? .refreshEvidence : .openNetwork
        )
    }

    static func listenerCheck(_ context: NodeDiagnosticContext) -> NodeDiagnosticCheck {
        guard context.networkInspection.inspectionSucceeded else {
            return check(
                id: "listeners", category: .network, state: .checking,
                title: "Required listeners", summary: "Inspecting the node's local listeners.",
                evidence: "The latest socket inspection is incomplete.", repair: .refreshEvidence
            )
        }
        if context.networkAssessment.state == .localConfigurationIssue {
            return check(
                id: "listeners", category: .network, state: .failed,
                title: "Required listeners", summary: "One or more configured listeners are missing.",
                evidence: "Open Network to see the exact locally configured ports.",
                observedAt: context.networkInspection.observedAt, repair: .openNetwork
            )
        }
        return check(
            id: "listeners", category: .network, state: .passed,
            title: "Required listeners", summary: "The configured local listeners are active.",
            evidence: "Socket state was verified on this Mac.", observedAt: context.networkInspection.observedAt
        )
    }

    static func inboundCheck(_ context: NodeDiagnosticContext) -> NodeDiagnosticCheck {
        let assessment = context.networkAssessment
        switch assessment.state {
        case .inboundVerified:
            return check(
                id: "inbound", category: .network, state: .passed,
                title: "Inbound reachability", summary: "Remote peer traffic has reached this node.",
                evidence: assessment.detail, observedAt: context.networkInspection.observedAt
            )
        case .reviewRouter:
            return check(
                id: "inbound", category: .network, state: .advisory,
                title: "Inbound reachability", summary: "No inbound evidence has appeared after the grace period.",
                evidence: assessment.detail, observedAt: context.networkInspection.observedAt, repair: .openNetwork
            )
        case .localConfigurationIssue:
            return check(
                id: "inbound", category: .network, state: .checking,
                title: "Inbound reachability",
                summary: "Reachability cannot be tested until local listeners are ready.",
                evidence: assessment.detail, repair: .openNetwork
            )
        case .waitingForEvidence:
            return check(
                id: "inbound", category: .network, state: .checking,
                title: "Inbound reachability", summary: "Listening locally; waiting for remote peer evidence.",
                evidence: assessment.detail, observedAt: context.networkInspection.observedAt
            )
        case .offline:
            return check(
                id: "inbound", category: .network, state: .checking,
                title: "Inbound reachability", summary: "Reachability is unavailable while the node is stopped.",
                evidence: assessment.detail
            )
        case .inspecting:
            return check(
                id: "inbound", category: .network, state: .checking,
                title: "Inbound reachability", summary: "Collecting inbound evidence.",
                evidence: assessment.detail, repair: .refreshEvidence
            )
        }
    }

    static func firewallCheck(_ context: NodeDiagnosticContext) -> NodeDiagnosticCheck {
        guard let firewall = context.firewall, firewall.nodeRule != .unavailable else {
            return check(
                id: "firewall", category: .network, state: .checking,
                title: "macOS Firewall", summary: "Firewall evidence is unavailable.",
                evidence: "Run a full check to query the authorized local service.", repair: .refreshEvidence
            )
        }
        if firewall.isReady {
            return check(
                id: "firewall", category: .network, state: .passed,
                title: "macOS Firewall", summary: "The node is allowed through macOS Firewall.",
                evidence: "Firewall enabled, block-all disabled, node rule allowed.", observedAt: firewall.verifiedAt
            )
        }
        if !firewall.globalEnabled {
            return check(
                id: "firewall", category: .network, state: .advisory,
                title: "macOS Firewall", summary: "macOS Firewall is off.",
                evidence:
                    "This does not block node traffic, but the Mac has less host-level protection. QuilNode can enable the firewall and allow only the node executable.",
                observedAt: firewall.verifiedAt, repair: .configureFirewall
            )
        }
        return check(
            id: "firewall", category: .network, state: .failed,
            title: "macOS Firewall", summary: "The firewall policy can block inbound node traffic.",
            evidence: "QuilNode can apply and verify the minimum node rule.",
            observedAt: firewall.verifiedAt, repair: .configureFirewall
        )
    }
}
