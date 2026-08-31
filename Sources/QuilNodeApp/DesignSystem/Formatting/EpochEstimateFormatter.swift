import Foundation
import QuilNodeCore

/// Shared presentation for pace-based epoch estimates.
///
/// Epoch timing is derived entirely from public node telemetry. Keeping the
/// formatter here avoids subtly different wording between the dashboard and
/// menu-bar surfaces.
enum EpochEstimateFormatter {
    static func compact(snapshot: NodeSnapshot, now: Date = Date()) -> String {
        guard snapshot.isRunning else { return "Node offline" }
        let progress = ChainProgressEvaluator.evaluate(snapshot, now: now)
        switch progress.state {
        case .archiveRecovery: return "Waiting on archives"
        case .localLag: return "Catching up"
        case .localStall: return "Waiting for frames"
        case .observing:
            if (progress.stagnantFor ?? 0) >= ChainProgressEvaluator.quietObservationThreshold {
                return "Waiting for frames"
            }
        case .advancing: break
        }
        return compact(
            framesRemaining: snapshot.epochClock.framesRemaining,
            framesPerMinute: snapshot.framesPerMinute
        )
    }

    static func compact(framesRemaining: UInt64, framesPerMinute: Double?) -> String {
        guard let duration = duration(framesRemaining: framesRemaining, framesPerMinute: framesPerMinute) else {
            return "ETA learning"
        }
        return duration.hasPrefix("<") ? "\(duration) left" : "~\(duration) left"
    }

    static func detailed(framesRemaining: UInt64, framesPerMinute: Double?) -> String {
        guard let duration = duration(framesRemaining: framesRemaining, framesPerMinute: framesPerMinute) else {
            return "ETA learning local pace"
        }
        return duration.hasPrefix("<") ? "\(duration) at local pace" : "~\(duration) at local pace"
    }

    private static func duration(framesRemaining: UInt64, framesPerMinute: Double?) -> String? {
        guard let framesPerMinute, framesPerMinute.isFinite, framesPerMinute > 0.05 else { return nil }

        let seconds = Double(framesRemaining) / framesPerMinute * 60
        guard seconds.isFinite, seconds < Double(Int.max) else { return nil }
        if seconds < 60 { return "<1m" }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = seconds >= 3_600 ? [.hour, .minute] : [.minute]
        formatter.maximumUnitCount = 2
        return formatter.string(from: seconds)
    }
}
