import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

enum NetworkStageKind: String, CaseIterable, Identifiable, Hashable {
    case listeners
    case firewall
    case gateway
    case internetBoundary
    case inboundPeers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .listeners: "Listeners"
        case .firewall: "macOS Firewall"
        case .gateway: "Gateway"
        case .internetBoundary: "Internet boundary"
        case .inboundPeers: "Inbound peers"
        }
    }

    var symbol: String {
        switch self {
        case .listeners: "dot.radiowaves.left.and.right"
        case .firewall: "firewall.fill"
        case .gateway: "wifi.router.fill"
        case .internetBoundary: "globe.americas.fill"
        case .inboundPeers: "point.3.connected.trianglepath.dotted"
        }
    }
}

enum NetworkStageState: String, Hashable {
    case verified
    case active
    case waiting
    case review
    case blocked
}

struct NetworkStagePresentation: Identifiable, Hashable {
    let kind: NetworkStageKind
    let state: NetworkStageState
    let status: String
    let value: String
    let detail: String
    let evidenceSource: String
    let observedAt: Date?
    let privacyField: PrivacyField?

    var id: NetworkStageKind { kind }
}

struct NetworkRouterTask: Identifiable, Hashable {
    enum State: Hashable {
        case complete
        case ready
        case manual
        case waiting
    }

    let id: Int
    let title: String
    let state: State
    let status: String
}

struct NetworkWorkspacePresentation {
    let title: String
    let detail: String
    let state: NetworkReadinessState
    let observedAt: Date?
    let stages: [NetworkStagePresentation]
    let routerTasks: [NetworkRouterTask]
    let gatewayAddress: String?
    let localAddress: String?
    let interfaceLabel: String
    let portPlan: NetworkPortPlan
    let routerAccess: RouterAccessDiscovery
    let firewall: ManagedFirewallStatus
    let inboundEvidence: Bool

    func stage(_ kind: NetworkStageKind) -> NetworkStagePresentation {
        stages.first { $0.kind == kind } ?? stages[0]
    }

    static func make(
        snapshot: NodeSnapshot,
        assessment: NetworkReadinessAssessment,
        inspection: NetworkLocalInspection,
        gateway: GatewayRouteAssessment,
        routerAccess: RouterAccessDiscovery,
        firewall: ManagedFirewallStatus,
        portPlan: NetworkPortPlan
    ) -> NetworkWorkspacePresentation {
        let listenersHealthy =
            inspection.inspectionSucceeded
            && portPlan.required.allSatisfy { inspection.isListening(for: $0) }
        let inboundEvents = snapshot.inboundConnectionsEstablished ?? 0
        let hasInbound = inboundEvents > 0 || inspection.inboundPeerSockets > 0
        let inspectionDate = inspection.inspectionSucceeded ? inspection.observedAt : nil
        let metricDate = snapshot.metricsUpdatedAt ?? snapshot.collectedAt
        let ports = portPlan.required.map(\.portLabel).joined(separator: " + ")

        let stages = [
            NetworkStagePresentation(
                kind: .listeners,
                state: listenersHealthy ? .verified : (inspection.inspectionSucceeded ? .blocked : .waiting),
                status: listenersHealthy ? "Verified" : (inspection.inspectionSucceeded ? "Missing" : "Checking"),
                value: listenersHealthy ? ports : listenerFallback(assessment),
                detail: listenersHealthy
                    ? "Required transports are listening on this process."
                    : "The inbound path cannot start until every required listener is active.",
                evidenceSource: "macOS socket table",
                observedAt: inspectionDate,
                privacyField: .networkPort
            ),
            NetworkStagePresentation(
                kind: .firewall,
                state: firewallState(firewall),
                status: firewallStatus(firewall),
                value: firewallValue(firewall, fallback: inspection.firewallState),
                detail: firewallDetail(firewall),
                evidenceSource: "QuilNode secure service",
                observedAt: firewall.nodeRule == .unavailable ? nil : firewall.verifiedAt,
                privacyField: nil
            ),
            NetworkStagePresentation(
                kind: .gateway,
                state: gatewayState(routerAccess),
                status: gatewayStatus(routerAccess),
                value: gateway.address ?? "Not detected",
                detail: routerAccess.detail,
                evidenceSource: "macOS default route + read-only local probe",
                observedAt: routerAccess.checkedAt ?? inspectionDate,
                privacyField: .networkIdentifier
            ),
            NetworkStagePresentation(
                kind: .internetBoundary,
                state: boundaryState(assessment: assessment, hasInbound: hasInbound),
                status: hasInbound ? "Observed" : boundaryStatus(assessment),
                value: hasInbound ? "Inbound crossed" : "Awaiting evidence",
                detail: hasInbound
                    ? "A remote connection crossed the local network boundary."
                    : "QuilNode waits for local inbound evidence; it does not use a remote port checker.",
                evidenceSource: "Node connection counter + live sockets",
                observedAt: hasInbound ? metricDate : inspectionDate,
                privacyField: .networkActivity
            ),
            NetworkStagePresentation(
                kind: .inboundPeers,
                state: hasInbound ? .verified : (snapshot.peers > 0 ? .active : .waiting),
                status: hasInbound ? "Established" : (snapshot.peers > 0 ? "Mesh active" : "Waiting"),
                value: snapshot.peers > 0 ? snapshot.peers.formatted() : "None observed",
                detail: hasInbound
                    ? "Current peer mesh; inbound events are counted separately and are not unique peers."
                    : "Peer count alone does not prove that this Mac accepted an inbound connection.",
                evidenceSource: "Local Quilibrium metrics",
                observedAt: snapshot.peers > 0 ? metricDate : nil,
                privacyField: .networkActivity
            ),
        ]

        let routerTasks = [
            NetworkRouterTask(
                id: 1,
                title: "Keep this Mac on the same LAN address",
                state: inspection.localIPv4 == nil ? .waiting : .ready,
                status: inspection.localIPv4 == nil ? "Detecting" : "Address ready"
            ),
            NetworkRouterTask(
                id: 2,
                title: "Forward only the verified node ports",
                state: hasInbound ? .complete : .manual,
                status: hasInbound ? "Proven by traffic" : "Router step"
            ),
            NetworkRouterTask(
                id: 3,
                title: "Save without enabling DMZ",
                state: .manual,
                status: "Manual safety check"
            ),
            NetworkRouterTask(
                id: 4,
                title: "Keep the node running for evidence",
                state: hasInbound ? .complete : .waiting,
                status: hasInbound ? "Evidence received" : "Watching locally"
            ),
        ]

        return NetworkWorkspacePresentation(
            title: assessment.title,
            detail: assessment.detail,
            state: assessment.state,
            observedAt: inspectionDate,
            stages: stages,
            routerTasks: routerTasks,
            gatewayAddress: gateway.address,
            localAddress: inspection.localIPv4,
            interfaceLabel: gateway.interfaceDisplayName ?? gateway.interfaceName ?? "Active route",
            portPlan: portPlan,
            routerAccess: routerAccess,
            firewall: firewall,
            inboundEvidence: hasInbound
        )
    }

    private static func listenerFallback(_ assessment: NetworkReadinessAssessment) -> String {
        assessment.missingMasterPorts.isEmpty
            ? "Checking"
            : assessment.missingMasterPorts.map(String.init).joined(separator: ", ")
    }

    private static func firewallState(_ firewall: ManagedFirewallStatus) -> NetworkStageState {
        if firewall.isReady { return .verified }
        if firewall.blockAllEnabled || firewall.nodeRule == .blocked { return .blocked }
        if firewall.nodeRule == .unavailable { return .waiting }
        return .review
    }

    private static func firewallStatus(_ firewall: ManagedFirewallStatus) -> String {
        if firewall.isReady { return "Allowing" }
        if firewall.blockAllEnabled || firewall.nodeRule == .blocked { return "Blocking" }
        if firewall.nodeRule == .unavailable { return "Checking" }
        return "Review"
    }

    private static func firewallValue(
        _ firewall: ManagedFirewallStatus,
        fallback: NetworkFirewallState
    ) -> String {
        if firewall.blockAllEnabled { return "Block all on" }
        if firewall.globalEnabled {
            switch firewall.nodeRule {
            case .allowed: return "Node allowed"
            case .blocked: return "Node blocked"
            case .missing: return "Rule missing"
            case .unavailable: break
            }
        }
        switch fallback {
        case .disabled: return "Firewall off"
        case .enabled: return "Firewall on"
        case .blockingAll: return "Block all on"
        case .unknown: return "Checking"
        }
    }

    private static func firewallDetail(_ firewall: ManagedFirewallStatus) -> String {
        if firewall.isReady {
            return firewall.managedByQuilNode
                ? "The current node binary is explicitly allowed and the rule is maintained after updates."
                : "The current node binary has an explicit inbound allow rule."
        }
        if firewall.blockAllEnabled { return "Block all overrides the node's application rule." }
        if firewall.nodeRule == .blocked { return "The current node binary is explicitly blocked." }
        if firewall.nodeRule == .missing { return "The current versioned node binary needs an explicit rule." }
        return "The secure local service is checking the minimum application rule."
    }

    private static func gatewayState(_ access: RouterAccessDiscovery) -> NetworkStageState {
        switch access.status {
        case .confirmed: .verified
        case .checking, .notChecked: .waiting
        case .unconfirmed, .unavailable: .review
        }
    }

    private static func gatewayStatus(_ access: RouterAccessDiscovery) -> String {
        switch access.status {
        case .confirmed: "Verified"
        case .checking: "Checking"
        case .notChecked: "Not checked"
        case .unconfirmed: "Page unconfirmed"
        case .unavailable: "Not inspectable"
        }
    }

    private static func boundaryState(
        assessment: NetworkReadinessAssessment,
        hasInbound: Bool
    ) -> NetworkStageState {
        if hasInbound { return .verified }
        switch assessment.state {
        case .offline, .localConfigurationIssue: return .blocked
        case .reviewRouter: return .review
        case .inspecting, .waitingForEvidence: return .waiting
        case .inboundVerified: return .verified
        }
    }

    private static func boundaryStatus(_ assessment: NetworkReadinessAssessment) -> String {
        switch assessment.state {
        case .offline: "Node offline"
        case .localConfigurationIssue: "Path incomplete"
        case .reviewRouter: "Review router"
        case .inspecting: "Checking"
        case .waitingForEvidence: "Waiting"
        case .inboundVerified: "Observed"
        }
    }
}
