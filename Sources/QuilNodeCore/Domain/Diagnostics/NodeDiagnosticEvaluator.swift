import Foundation

/// Evaluates independent health signals instead of collapsing process
/// existence, readiness, and progress into one ambiguous status. The rules are
/// deterministic and side-effect free; UI repairs remain explicit actions.
public enum NodeDiagnosticEvaluator {
    public static func evaluate(_ context: NodeDiagnosticContext) -> NodeDiagnosticReport {
        let snapshot = context.snapshot
        let now = context.now
        let uptime = NodeProcessUptimeParser.seconds(from: snapshot.processUptime)
        var checks = [
            serviceCheck(context),
            processCheck(context),
            telemetryCheck(context),
            frameCheck(context, uptime: uptime),
            peerCheck(context, uptime: uptime),
            listenerCheck(context),
            inboundCheck(context),
            firewallCheck(context),
            qclientCheck(context),
            versionCheck(context),
        ]

        if let allocationCheck = allocationEpochCheck(context) {
            checks.append(allocationCheck)
        }

        if !snapshot.recentWarnings.isEmpty {
            let progress = ChainProgressEvaluator.evaluate(snapshot, now: now)
            let recoveryMessageCount = snapshot.recentWarnings.count(
                where: ChainProgressLogParser.isArchiveRecoveryMessage)
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
}
