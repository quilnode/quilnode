import Foundation
import QuilNodeCore

struct WorkerExecutionPresentation {
    enum Tone { case neutral, progress, warning }

    let observation: WorkerExecutionObservation?
    let nodeRunning: Bool
    var now: Date = Date()

    var isCurrent: Bool { nodeRunning && observation?.isFresh(at: now) == true }

    var title: String {
        guard nodeRunning else { return "Node stopped" }
        guard let observation else { return "Not reported" }
        guard observation.state != "unknown" else { return "Not reported" }
        guard isCurrent else { return "Last read outdated" }
        switch observation.state {
        case "start", "starting": return "Starting"
        case "wait", "waiting": return "Waiting"
        case "sync", "syncing": return "Syncing"
        case "serve", "serving": return "Serving"
        case "close", "closing": return "Closing"
        case "handoff": return "Handoff"
        case "blocked": return "Blocked"
        case "stopped": return "Stopped"
        case "running": return "Host running"
        default: return "Not reported"
        }
    }

    var needsReview: Bool {
        isCurrent
            && (observation?.state == "blocked" || observation?.state == "stopped"
                || (observation?.recoveryFailures ?? 0) > 0)
    }

    var tone: Tone {
        if needsReview { return .warning }
        return isCurrent ? .progress : .neutral
    }

    var detail: String {
        guard let observation else { return "This node did not return worker execution telemetry." }
        if !nodeRunning { return "Last worker observation retained; the node is stopped." }
        if !isCurrent { return "Waiting for a current worker observation." }
        if let blocker = observation.blocker { return blocker }
        if let phase = observation.recoveryPhase, phase != "idle" {
            return "Recovery: " + phase.replacingOccurrences(of: "_", with: " ")
        }
        if let recorded = observation.sealRecorded {
            return recorded ? "Session seal recorded by GLOBAL" : "Session seal awaiting GLOBAL recording"
        }
        return "Host state does not establish proof production or reward credit."
    }

    var frameText: String { observation?.frame.map(\.grouped) ?? "—" }

    var advanceText: String {
        ObservationFreshness(observedAt: observation?.lastAdvanceAt, now: now, maximumAge: .infinity).label
    }
}
