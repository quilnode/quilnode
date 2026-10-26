import Foundation
import QuilNodeCore

struct OverviewStatusPresentation {
    let snapshot: NodeSnapshot
    let phase: NodeObservationPhase
    var now: Date = Date()

    var freshness: ObservationFreshness {
        ObservationFreshness(observedAt: phase.hasLiveTelemetry ? snapshot.collectedAt : nil, now: now, maximumAge: 30)
    }

    var workersNeedingReview: Int {
        (snapshot.localWorkers ?? []).filter {
            WorkerExecutionPresentation(observation: $0.execution, nodeRunning: snapshot.isRunning, now: now)
                .needsReview
        }.count
    }

    private var chain: ChainProgressAssessment { ChainProgressEvaluator.evaluate(snapshot, now: now) }

    var needsAttention: Bool {
        phase.hasLiveTelemetry
            && (!snapshot.isRunning || !freshness.isCurrent || workersNeedingReview > 0
                || chain.state == .localLag || chain.state == .localStall)
    }

    var title: String {
        if phase == .checkingProcess { return "Checking this Mac" }
        if phase == .loadingTelemetry { return snapshot.isRunning ? "Loading node readings" : "Node stopped" }
        if !freshness.isCurrent { return "Node readings are outdated" }
        if !snapshot.isRunning { return "Node stopped" }
        if workersNeedingReview > 0 { return "Node running · review workers" }
        switch chain.state {
        case .archiveRecovery: return "Node running · recovering"
        case .localLag: return "Node running · catching up"
        case .localStall: return "Node running · review progress"
        case .advancing, .observing: return "Node running"
        }
    }

    var detail: String {
        if !phase.hasLiveTelemetry {
            return "Reading the local service, then loading worker, network and wallet observations."
        }
        if !freshness.isCurrent { return "The latest local check is overdue. Values below are the last observations." }
        if !snapshot.isRunning {
            return "The managed node service is stopped. Open Diagnostics for the available actions."
        }
        if workersNeedingReview > 0 {
            return
                "Some workers report a blocked host or failed recovery attempts. Active assignments alone do not establish production."
        }
        if chain.state == .localLag {
            return "A reachable archive reports a newer frame. Review the local progress evidence."
        }
        if chain.state == .localStall {
            return "Local frame progress needs review. Inspect the evidence before restarting."
        }
        return "Readings come from this Mac. Assignments, worker execution and rewards are tracked separately."
    }

    var symbol: String {
        if !phase.hasLiveTelemetry { return "ellipsis.circle" }
        if needsAttention { return "exclamationmark.circle" }
        return "waveform.path.ecg"
    }
}
