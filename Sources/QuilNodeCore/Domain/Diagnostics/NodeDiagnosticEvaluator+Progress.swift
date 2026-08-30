import Foundation

extension NodeDiagnosticEvaluator {
    static func frameCheck(_ context: NodeDiagnosticContext, uptime: TimeInterval?) -> NodeDiagnosticCheck {
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
}
