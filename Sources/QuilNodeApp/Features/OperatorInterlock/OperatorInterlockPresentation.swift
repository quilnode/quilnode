import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

enum OperatorInterlockPresentation {
    static func lifecycle(_ action: NodeLifecycleAction) -> OperatorInterlockModel {
        switch action {
        case .start:
            return startNode
        case .restart:
            return restartNode
        case .stop:
            return stopNode
        }
    }

    static func diagnostic(_ repair: NodeDiagnosticRepair) -> OperatorInterlockModel {
        switch repair {
        case .restartNode:
            return restartNode.reidentified(
                as: "diagnostic-restart",
                eyebrow: "DIAGNOSTIC REPAIR",
                outcome: "Restart the managed process, then rerun local checks against fresh evidence."
            )
        case .configureFirewall:
            return firewallRepair
        default:
            return genericRepair(repair)
        }
    }

    static func updatePolicy(_ policy: NodeUpdatePolicy) -> OperatorInterlockModel {
        let channel = updateChannel(for: policy)
        return OperatorInterlockModel(
            id: "update-policy-\(policy.rawValue)",
            eyebrow: "UPDATE TRUST POLICY",
            title: "Enable \(policy.title) updates",
            outcome: channel.outcome,
            symbol: channel.symbol,
            tone: channel.tone,
            steps: [
                .init(
                    id: "observe",
                    title: "Observe channel",
                    detail: channel.observeDetail,
                    symbol: "antenna.radiowaves.left.and.right",
                    tone: .information
                ),
                .init(
                    id: "verify",
                    title: "Verify candidate",
                    detail: channel.verifyDetail,
                    symbol: "checkmark.shield.fill",
                    tone: channel.tone
                ),
                .init(
                    id: "activate",
                    title: "Guarded activation",
                    detail: "Stage first, retain rollback, then restart the node.",
                    symbol: "arrow.triangle.2.circlepath",
                    tone: .success
                ),
            ],
            changes: [
                .init(
                    id: "policy",
                    title: "Automatic policy",
                    detail: "The six-hour schedule follows only \(channel.scopeDetail).",
                    symbol: "clock.badge.checkmark"
                ),
                .init(
                    id: "runtime",
                    title: "Managed runtime",
                    detail: "A qualifying candidate may replace the node binary after preparation succeeds.",
                    symbol: "shippingbox.fill"
                ),
            ],
            preserved: standardNodeBoundary + [
                .init(
                    id: "rollback",
                    title: "Previous runtime",
                    detail: "The installed binary remains active until activation and is retained for rollback.",
                    symbol: "arrow.uturn.backward.circle.fill"
                )
            ],
            verification: channel.verification,
            trustNote: channel.trustNote,
            decisions: updateDecisions,
            defaultDecisionID: "now",
            cancelTitle: "Cancel"
        )
    }

    static let quitDuringUpdate = OperatorInterlockModel(
        id: "quit-during-update",
        eyebrow: "ACTIVE UPDATE",
        title: "An update is still running",
        outcome: "QuilNode can finish the preparation with every dashboard window closed.",
        symbol: "exclamationmark.arrow.triangle.2.circlepath",
        tone: .warning,
        steps: [
            .init(
                id: "interrupt",
                title: "Interrupt work",
                detail: "Stop the current download or build before activation.",
                symbol: "pause.fill",
                tone: .warning
            ),
            .init(
                id: "close",
                title: "Close QuilNode",
                detail: "End monitoring and the current update session.",
                symbol: "xmark.app.fill",
                tone: .warning
            ),
            .init(
                id: "retain",
                title: "Keep current node",
                detail: "Leave the installed runtime and service state unchanged.",
                symbol: "checkmark.shield.fill",
                tone: .success
            ),
        ],
        changes: [
            .init(
                id: "update-session",
                title: "Current update session",
                detail: "The in-progress preparation is interrupted and can be started again later.",
                symbol: "hammer.fill"
            )
        ],
        preserved: standardNodeBoundary + [
            .init(
                id: "service-state",
                title: "Node service state",
                detail: "Quitting the controller does not stop or restart the managed node.",
                symbol: "power.circle.fill"
            )
        ],
        verification: ["Installed node retained", "Service command not sent", "Key material untouched"],
        trustNote: "Keep Running is safest: the update continues in the background without a dashboard window.",
        decisions: [
            .init(
                id: "quit",
                title: "Quit anyway",
                detail: "Interrupt only the current QuilNode update session.",
                actionTitle: "Quit anyway",
                symbol: "xmark.app.fill",
                tone: .destructive,
                bullets: []
            )
        ],
        defaultDecisionID: "quit",
        cancelTitle: "Keep Running"
    )

    private static let startNode = OperatorInterlockModel(
        id: "start-node",
        eyebrow: "NODE LIFECYCLE",
        title: "Start node",
        outcome: "Load the managed service, reconnect locally, and verify fresh telemetry.",
        symbol: "play.circle.fill",
        tone: .success,
        steps: [
            .init(
                id: "load", title: "Load service", detail: "Start the managed process.", symbol: "play.fill",
                tone: .success),
            .init(
                id: "connect", title: "Reconnect", detail: "Open listeners and reconnect peers.", symbol: "network",
                tone: .information),
            .init(
                id: "verify", title: "Verify telemetry", detail: "Refresh process and frame evidence.",
                symbol: "waveform.path.ecg", tone: .success),
        ],
        changes: [
            .init(
                id: "process", title: "Node process", detail: "The managed node service starts running.",
                symbol: "power.circle.fill"),
            .init(
                id: "network", title: "Network participation", detail: "Configured listeners and peer sessions resume.",
                symbol: "network"),
        ],
        preserved: standardNodeBoundary,
        verification: ["Process running", "Listeners observed", "Fresh local telemetry"],
        trustNote: "The request goes only to QuilNode’s authenticated local service.",
        decisions: [
            .init(
                id: "start", title: "Start node", detail: "Resume local node participation.", actionTitle: "Start node",
                symbol: "play.fill", tone: .success, bullets: [])
        ],
        defaultDecisionID: "start",
        cancelTitle: "Cancel"
    )

    private static let restartNode = OperatorInterlockModel(
        id: "restart-node",
        eyebrow: "NODE LIFECYCLE",
        title: "Restart node",
        outcome: "Pause the managed process briefly, resume it, and verify recovery automatically.",
        symbol: "arrow.clockwise.circle.fill",
        tone: .information,
        steps: [
            .init(
                id: "pause", title: "Pause service", detail: "Stop the managed process cleanly.", symbol: "pause.fill",
                tone: .information),
            .init(
                id: "resume", title: "Resume service", detail: "Load the same runtime and settings.",
                symbol: "play.fill", tone: .information),
            .init(
                id: "verify", title: "Verify telemetry", detail: "Refresh process, frame, and peer evidence.",
                symbol: "waveform.path.ecg", tone: .success),
        ],
        changes: [
            .init(
                id: "process", title: "Node process", detail: "The managed process stops briefly and starts again.",
                symbol: "arrow.clockwise"),
            .init(
                id: "connections", title: "Peer sessions", detail: "Live sessions reconnect after the service resumes.",
                symbol: "network"),
        ],
        preserved: standardNodeBoundary,
        verification: ["Process running", "Frame evidence refreshed", "Peer recovery observed"],
        trustNote: "This action is local. It does not alter your identity or submit a network transaction.",
        decisions: [
            .init(
                id: "restart", title: "Restart node", detail: "Briefly pause and resume the managed service.",
                actionTitle: "Restart node", symbol: "arrow.clockwise", tone: .information, bullets: [])
        ],
        defaultDecisionID: "restart",
        cancelTitle: "Cancel"
    )

    private static let stopNode = OperatorInterlockModel(
        id: "stop-node",
        eyebrow: "NODE LIFECYCLE",
        title: "Stop node",
        outcome: "Unload the managed process and pause network participation until you start it again.",
        symbol: "stop.circle.fill",
        tone: .destructive,
        steps: [
            .init(
                id: "request", title: "Request stop", detail: "Ask the local service to unload the node.",
                symbol: "stop.fill", tone: .destructive),
            .init(
                id: "disconnect", title: "Close sessions", detail: "Listeners and peers stop with the process.",
                symbol: "network.slash", tone: .warning),
            .init(
                id: "confirm", title: "Confirm stopped", detail: "Refresh local process evidence.",
                symbol: "checkmark.circle.fill", tone: .success),
        ],
        changes: [
            .init(
                id: "process", title: "Node process", detail: "The managed service is unloaded.", symbol: "power.circle"
            ),
            .init(
                id: "participation", title: "Network participation",
                detail: "Proving and peer sessions pause while stopped.", symbol: "pause.circle.fill"),
        ],
        preserved: standardNodeBoundary,
        verification: ["Process stopped", "Listeners closed", "Local data retained"],
        trustNote: "Stopping does not delete stores or retire the node identity; it only pauses the service.",
        decisions: [
            .init(
                id: "stop", title: "Stop node", detail: "Pause the managed service until manually restarted.",
                actionTitle: "Stop node", symbol: "stop.fill", tone: .destructive, bullets: [])
        ],
        defaultDecisionID: "stop",
        cancelTitle: "Cancel"
    )

    private static let firewallRepair = OperatorInterlockModel(
        id: "diagnostic-firewall",
        eyebrow: "DIAGNOSTIC REPAIR",
        title: "Configure macOS Firewall",
        outcome: "Apply the minimum local rule for the installed node, then verify the effective firewall state.",
        symbol: "firewall.fill",
        tone: .information,
        steps: [
            .init(
                id: "inspect", title: "Inspect rule", detail: "Read the current local firewall state.",
                symbol: "doc.text.magnifyingglass", tone: .information),
            .init(
                id: "apply", title: "Apply minimum", detail: "Allow only the installed node executable.",
                symbol: "checkmark.shield.fill", tone: .information),
            .init(
                id: "verify", title: "Verify result", detail: "Confirm firewall and executable status.",
                symbol: "checkmark.circle.fill", tone: .success),
        ],
        changes: [
            .init(
                id: "binary-rule", title: "Installed node rule",
                detail: "The current managed node executable is added or unblocked.", symbol: "app.badge.checkmark"),
            .init(
                id: "block-all", title: "Block-all mode",
                detail: "Disabled only if it prevents the explicit node rule from working.", symbol: "switch.2"),
        ],
        preserved: standardNodeBoundary + [
            .init(
                id: "router", title: "Router configuration",
                detail: "No gateway page, NAT rule, or port mapping is changed.", symbol: "wifi.router.fill")
        ],
        verification: ["Firewall remains enabled", "Node executable allowed", "Router untouched"],
        trustNote: "macOS may request administrator approval. QuilNode never receives or stores the password.",
        decisions: [
            .init(
                id: "configure", title: "Configure firewall", detail: "Apply and verify the minimum local rule.",
                actionTitle: "Configure firewall", symbol: "firewall.fill", tone: .information, bullets: [])
        ],
        defaultDecisionID: "configure",
        cancelTitle: "Cancel"
    )

    private static let updateDecisions: [OperatorInterlockDecision] = [
        .init(
            id: "now",
            title: "Enable and check now",
            detail: "Save the policy, then inspect the selected channel immediately.",
            actionTitle: "Enable & check now",
            symbol: "bolt.fill",
            tone: .information,
            bullets: ["Starts one check now", "Keeps the six-hour schedule"]
        ),
        .init(
            id: "later",
            title: "Enable for later",
            detail: "Save the policy without starting a foreground check.",
            actionTitle: "Enable for later",
            symbol: "clock.fill",
            tone: .accent,
            bullets: ["No check starts now", "Runs on the six-hour schedule"]
        ),
    ]

    private static let standardNodeBoundary: [OperatorInterlockScopeItem] = [
        .init(
            id: "identity", title: "Identity and keys",
            detail: "The active keyset and every private key byte remain untouched.", symbol: "person.badge.key.fill"),
        .init(
            id: "stores", title: "Stores",
            detail: "Frame, clock, hypergraph, and proving stores are not deleted or replaced.",
            symbol: "externaldrive.fill"),
        .init(
            id: "configuration", title: "Configuration",
            detail: "Node settings, ports, peers, and app preferences remain unchanged.", symbol: "gearshape.fill"),
        .init(
            id: "binary", title: "Node binary", detail: "The installed runtime and version are not replaced.",
            symbol: "shippingbox.fill"),
    ]

    private static func genericRepair(_ repair: NodeDiagnosticRepair) -> OperatorInterlockModel {
        restartNode.reidentified(
            as: "diagnostic-\(repair.rawValue)",
            eyebrow: "DIAGNOSTIC REPAIR",
            outcome: "Run the scoped local repair, then refresh diagnostics against new evidence."
        )
    }

    private struct UpdateChannelCopy {
        let outcome: String
        let symbol: String
        let tone: OperatorInterlockTone
        let observeDetail: String
        let verifyDetail: String
        let scopeDetail: String
        let verification: [String]
        let trustNote: String
    }

    private static func updateChannel(for policy: NodeUpdatePolicy) -> UpdateChannelCopy {
        switch policy {
        case .manual:
            return .init(
                outcome: "Keep all node runtime updates under explicit operator control.",
                symbol: "hand.raised.fill",
                tone: .accent,
                observeDetail: "No automatic channel is polled.",
                verifyDetail: "Every future install stays manual.",
                scopeDetail: "explicit operator requests",
                verification: ["Automatic schedule disabled", "Current runtime retained"],
                trustNote: "This setting changes scheduling only; it never changes node data."
            )
        case .signedStable:
            return .init(
                outcome: "Follow only strictly newer official releases that pass digest and Ed448 quorum verification.",
                symbol: "checkmark.seal.fill",
                tone: .success,
                observeDetail: "Read the official signed release channel.",
                verifyDetail: "Require SHA3-256 and the seven-signature quorum.",
                scopeDetail: "strictly newer signed releases",
                verification: ["Release is newer", "Digest matches", "Signature quorum passes", "Rollback retained"],
                trustNote: "A signed stable policy never automatically downgrades the installed .25 runtime."
            )
        case .approvedDevelopment:
            return .init(
                outcome: "Follow only the exact commit approved by the subpatch marker on the highest version branch.",
                symbol: "checkmark.shield.fill",
                tone: .information,
                observeDetail: "Track the highest official version branch.",
                verifyDetail: "Bind the root subpatch marker to one exact commit.",
                scopeDetail: "marker-approved development commits",
                verification: [
                    "Highest version branch", "Marker commit bound", "Source build verified", "Rollback retained",
                ],
                trustNote: "Later unmarked commits are excluded even when they exist on the same branch."
            )
        case .bleedingEdge:
            return .init(
                outcome:
                    "Follow the newest raw commit across official branches, including potentially unfinished work.",
                symbol: "exclamationmark.triangle.fill",
                tone: .warning,
                observeDetail: "Track the newest official repository commit.",
                verifyDetail: "Build the exact commit locally; no approval marker is required.",
                scopeDetail: "the newest raw official commit",
                verification: ["Commit resolved", "Local build succeeds", "Artifact staged", "Rollback retained"],
                trustNote: "Raw development is intentionally high risk and may fail to build or run."
            )
        }
    }
}

private extension OperatorInterlockModel {
    func reidentified(as id: String, eyebrow: String, outcome: String) -> OperatorInterlockModel {
        OperatorInterlockModel(
            id: id,
            eyebrow: eyebrow,
            title: title,
            outcome: outcome,
            symbol: symbol,
            tone: tone,
            steps: steps,
            changes: changes,
            preserved: preserved,
            verification: verification,
            trustNote: trustNote,
            decisions: decisions,
            defaultDecisionID: defaultDecisionID,
            cancelTitle: cancelTitle
        )
    }
}
