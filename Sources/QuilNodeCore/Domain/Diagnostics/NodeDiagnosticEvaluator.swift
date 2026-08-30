import Foundation

/// Evaluates independent health signals instead of collapsing process
/// existence, readiness, and progress into one ambiguous status. The rules are
/// deterministic and side-effect free; UI repairs remain explicit actions.
public enum NodeDiagnosticEvaluator {
    public static func evaluate(_ context: NodeDiagnosticContext) -> NodeDiagnosticReport {
        let snapshot = context.snapshot
        let now = context.now
        let uptime = NodeProcessUptimeParser.seconds(from: snapshot.processUptime)
        var checks: [NodeDiagnosticCheck] = []

        checks.append(serviceCheck(context))
        checks.append(processCheck(context))
        checks.append(telemetryCheck(context))
        checks.append(frameCheck(context, uptime: uptime))
        checks.append(peerCheck(context, uptime: uptime))
        checks.append(listenerCheck(context))
        checks.append(inboundCheck(context))
        checks.append(firewallCheck(context))
        checks.append(qclientCheck(context))
        checks.append(versionCheck(context))

        if !snapshot.recentWarnings.isEmpty {
            let progress = ChainProgressEvaluator.evaluate(snapshot, now: now)
            let recoveryMessageCount = snapshot.recentWarnings.count(
                where: ChainProgressLogParser.isArchiveRecoveryMessage)
            // A bounded five-line window can contain one unrelated transient
            // while archive retries dominate. Independent process, telemetry,
            // listener, and tooling checks still surface real local failures.
            let recoveryDominates =
                progress.state == .archiveRecovery
                && recoveryMessageCount >= max(snapshot.recentWarnings.count - 1, 1)
            checks.append(
                NodeDiagnosticCheck(
                    id: "recent-evidence",
                    category: .runtime,
                    state: recoveryDominates ? .waiting : .advisory,
                    title: recoveryDominates ? "Recovery evidence" : "Recent local messages",
                    summary: recoveryDominates
                        ? "Recent messages match the archive recovery already identified below."
                        : "The latest local log window contains \(snapshot.recentWarnings.count) warning or error messages.",
                    evidence: recoveryDominates
                        ? "These retries are expected while archive state converges; no local repair is recommended."
                        : "Review the sanitized evidence below before restarting anything.",
                    observedAt: snapshot.logLastModifiedAt,
                    repair: recoveryDominates ? nil : .refreshEvidence
                ))
        }

        return NodeDiagnosticReport(generatedAt: now, checks: checks)
    }

    private static func serviceCheck(_ context: NodeDiagnosticContext) -> NodeDiagnosticCheck {
        switch context.serviceAvailable {
        case nil:
            return check(
                id: "operator-service", category: .runtime, state: .checking,
                title: "Operator service", summary: "Checking the authorized local service.",
                evidence: "No service result has been collected yet.", repair: .refreshEvidence
            )
        case true:
            return check(
                id: "operator-service", category: .runtime, state: .passed,
                title: "Operator service", summary: "Authorized lifecycle operations are available.",
                evidence: "The code-signature-pinned local service answered successfully."
            )
        case false:
            return check(
                id: "operator-service", category: .runtime, state: .failed,
                title: "Operator service", summary: "Lifecycle operations are unavailable.",
                evidence: "The local service did not pass its availability check.", repair: .openUpdates
            )
        }
    }

    private static func processCheck(_ context: NodeDiagnosticContext) -> NodeDiagnosticCheck {
        guard context.initialRefreshComplete else {
            return check(
                id: "process", category: .runtime, state: .checking,
                title: "Node process", summary: "Looking for the local node process.",
                evidence: "The first process probe has not completed.", repair: .refreshEvidence
            )
        }
        if context.snapshot.isRunning {
            return check(
                id: "process", category: .runtime, state: .passed,
                title: "Node process", summary: "The node process is alive.",
                evidence: context.snapshot.processID.map { "Local process ID \($0) is present." }
                    ?? "Process evidence is present.",
                observedAt: context.snapshot.collectedAt
            )
        }
        return check(
            id: "process", category: .runtime, state: .failed,
            title: "Node process", summary: "The node process is not running.",
            evidence: "A completed local process probe found no active node.",
            observedAt: context.snapshot.collectedAt, repair: .startNode
        )
    }

    private static func telemetryCheck(_ context: NodeDiagnosticContext) -> NodeDiagnosticCheck {
        guard context.initialRefreshComplete else {
            return check(
                id: "telemetry", category: .runtime, state: .checking,
                title: "Local telemetry", summary: "Waiting for local evidence.",
                evidence: "Metrics and log freshness have not been evaluated.", repair: .refreshEvidence
            )
        }
        guard context.snapshot.isRunning else {
            return check(
                id: "telemetry", category: .runtime, state: .checking,
                title: "Local telemetry", summary: "Telemetry is unavailable while the node is stopped.",
                evidence: "Start the node before evaluating telemetry."
            )
        }
        let dates = [context.snapshot.metricsUpdatedAt, context.snapshot.logLastModifiedAt].compactMap { $0 }
        guard let newest = dates.max() else {
            return check(
                id: "telemetry", category: .runtime, state: .advisory,
                title: "Local telemetry",
                summary: "The process is alive, but no fresh metric or log timestamp is available.",
                evidence: "This can occur briefly during startup.", repair: .refreshEvidence
            )
        }
        let age = max(context.now.timeIntervalSince(newest), 0)
        let state: NodeDiagnosticState = age < 90 ? .passed : (age < 300 ? .advisory : .failed)
        return check(
            id: "telemetry", category: .runtime, state: state,
            title: "Local telemetry",
            summary: state == .passed ? "Local evidence is fresh." : "Local evidence is \(ageDescription(age)) old.",
            evidence: "Newest local metric or log observation: \(newest.formatted(date: .omitted, time: .standard)).",
            observedAt: newest, repair: state == .passed ? nil : .refreshEvidence
        )
    }

    private static func frameCheck(_ context: NodeDiagnosticContext, uptime: TimeInterval?) -> NodeDiagnosticCheck {
        let snapshot = context.snapshot
        guard context.initialRefreshComplete, snapshot.isRunning else {
            return check(
                id: "frame-progress", category: .progress, state: .checking,
                title: "Frame progress", summary: "Frame readiness has not been established.",
                evidence: snapshot.isRunning ? "Waiting for the first frame sample." : "The node must be running."
            )
        }
        guard snapshot.frame > 0 else {
            let warming = (uptime ?? 0) < 180
            return check(
                id: "frame-progress", category: .progress, state: warming ? .checking : .failed,
                title: "Frame progress",
                summary: warming ? "Waiting for the first frame." : "No frame has been observed after startup.",
                evidence: "The local status stream currently reports frame 0.",
                repair: warming ? .refreshEvidence : .restartNode
            )
        }
        let progress = ChainProgressEvaluator.evaluate(snapshot, now: context.now)
        if progress.state == .archiveRecovery, snapshot.frameLastAdvancedAt == nil {
            let archiveCount = snapshot.archiveEndpointCount ?? 0
            return check(
                id: "frame-progress", category: .progress, state: .waiting,
                title: "Archive recovery",
                summary: "The network head is waiting for archive state to converge.",
                evidence:
                    "Frame \(snapshot.frame) matches archive head evidence; \(archiveCount) archive source\(archiveCount == 1 ? " is" : "s are") available to the local sync pool and recovery retries remain fresh. Keep the node running—no restart or store wipe is recommended.",
                observedAt: progress.evidence?.observedAt
            )
        }
        guard let advancedAt = snapshot.frameLastAdvancedAt else {
            return check(
                id: "frame-progress", category: .progress, state: .checking,
                title: "Frame progress", summary: "Establishing a frame movement baseline.",
                evidence: "At least two frame observations are required.", repair: .refreshEvidence
            )
        }
        let age = max(context.now.timeIntervalSince(advancedAt), 0)
        let rateEvidence =
            snapshot.framesPerMinute.map { String(format: "%.2f frames/minute", $0) }
            ?? "rate still calibrating"

        switch progress.state {
        case .advancing:
            return check(
                id: "frame-progress", category: .progress, state: .passed,
                title: "Frame progress", summary: "Frames are advancing.",
                evidence: "Frame \(snapshot.frame) · \(rateEvidence).", observedAt: advancedAt
            )
        case .archiveRecovery:
            let archiveCount = snapshot.archiveEndpointCount ?? 0
            return check(
                id: "frame-progress", category: .progress, state: .waiting,
                title: "Archive recovery",
                summary: "The network head is waiting for archive state to converge.",
                evidence:
                    "Frame \(snapshot.frame) has been unchanged for \(ageDescription(age)); \(archiveCount) archive source\(archiveCount == 1 ? " is" : "s are") available, archive head evidence agrees with this frame, and local recovery retries remain fresh. Keep the node running—no restart or store wipe is recommended.",
                observedAt: progress.evidence?.observedAt
            )
        case .localLag:
            let remote = progress.evidence?.highestArchiveFrame
            let remoteDetail =
                remote.map { "A reachable archive reports frame \($0)." }
                ?? "A reachable archive reports a newer frame."
            let requiresAction = age >= 10 * 60
            return check(
                id: "frame-progress", category: .progress,
                state: requiresAction ? .failed : .advisory,
                title: "Local synchronization lag",
                summary: "Archive peers are ahead of this node.",
                evidence: "Local frame \(snapshot.frame) · \(remoteDetail)",
                observedAt: progress.evidence?.observedAt,
                repair: requiresAction ? .restartNode : .refreshEvidence
            )
        case .observing:
            return check(
                id: "frame-progress", category: .progress, state: age < 120 ? .passed : .checking,
                title: "Frame progress",
                summary: age < 120 ? "Frames are advancing." : "Watching a quiet frame interval before diagnosing it.",
                evidence: "Frame \(snapshot.frame) has been unchanged for \(ageDescription(age)) · \(rateEvidence).",
                observedAt: advancedAt,
                repair: age < 120 ? nil : .refreshEvidence
            )
        case .localStall:
            return check(
                id: "frame-progress", category: .progress, state: .advisory,
                title: "Progress cause unresolved",
                summary: "The frame is quiet, but local evidence does not justify an automatic restart.",
                evidence:
                    "Frame \(snapshot.frame) has been unchanged for \(ageDescription(age)). Refresh all probes; peer, listener, and telemetry checks identify the next safe repair without guessing.",
                observedAt: advancedAt, repair: .refreshEvidence
            )
        }
    }

    private static func peerCheck(_ context: NodeDiagnosticContext, uptime: TimeInterval?) -> NodeDiagnosticCheck {
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

    private static func listenerCheck(_ context: NodeDiagnosticContext) -> NodeDiagnosticCheck {
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

    private static func inboundCheck(_ context: NodeDiagnosticContext) -> NodeDiagnosticCheck {
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

    private static func firewallCheck(_ context: NodeDiagnosticContext) -> NodeDiagnosticCheck {
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

    private static func qclientCheck(_ context: NodeDiagnosticContext) -> NodeDiagnosticCheck {
        guard let ready = context.qclientReady, let compatible = context.qclientCompatible else {
            return check(
                id: "qclient", category: .tooling, state: .checking,
                title: "qclient", summary: "qclient provenance has not been inspected.",
                evidence: "The installation preflight has not completed.", repair: .refreshEvidence
            )
        }
        if ready && compatible {
            return check(
                id: "qclient", category: .tooling, state: .passed,
                title: "qclient", summary: "The local client is trusted and matches the node.",
                evidence: "Provenance and node compatibility passed."
            )
        }
        return check(
            id: "qclient", category: .tooling, state: .failed,
            title: "qclient",
            summary: ready ? "qclient does not match the installed node." : "A trusted qclient is not installed.",
            evidence: "Install the client matching the active node build.", repair: .repairQClient
        )
    }

    private static func versionCheck(_ context: NodeDiagnosticContext) -> NodeDiagnosticCheck {
        guard context.initialRefreshComplete else {
            return check(
                id: "version", category: .tooling, state: .checking,
                title: "Node build identity", summary: "Reading the installed build identity.",
                evidence: "The first local probe has not completed."
            )
        }
        guard let version = context.snapshot.version, !version.isEmpty else {
            return check(
                id: "version", category: .tooling, state: .advisory,
                title: "Node build identity", summary: "The running version could not be identified.",
                evidence: "Refresh deep node information before updating.", repair: .refreshEvidence
            )
        }
        return check(
            id: "version", category: .tooling, state: .passed,
            title: "Node build identity", summary: "The running build reports version \(version).",
            evidence: "Version identity came from the local node."
        )
    }

    private static func check(
        id: String,
        category: NodeDiagnosticCategory,
        state: NodeDiagnosticState,
        title: String,
        summary: String,
        evidence: String,
        observedAt: Date? = nil,
        repair: NodeDiagnosticRepair? = nil
    ) -> NodeDiagnosticCheck {
        NodeDiagnosticCheck(
            id: id,
            category: category,
            state: state,
            title: title,
            summary: summary,
            evidence: evidence,
            observedAt: observedAt,
            repair: repair
        )
    }

    private static func ageDescription(_ seconds: TimeInterval) -> String {
        if seconds < 60 { return "\(Int(seconds.rounded())) seconds" }
        if seconds < 3_600 { return "\(Int((seconds / 60).rounded())) minutes" }
        return "\(Int((seconds / 3_600).rounded())) hours"
    }
}
