import Foundation

/// Shared presentation for pace-based epoch estimates.
///
/// Epoch timing is derived entirely from public node telemetry. Keeping the
/// formatter here avoids subtly different wording between the dashboard and
/// menu-bar surfaces.
enum EpochEstimateFormatter {
    static func compact(framesRemaining: UInt64, framesPerMinute: Double?) -> String {
        guard let duration = duration(framesRemaining: framesRemaining, framesPerMinute: framesPerMinute) else {
            return "ETA learning"
        }
        return "~\(duration) left"
    }

    static func detailed(framesRemaining: UInt64, framesPerMinute: Double?) -> String {
        guard let duration = duration(framesRemaining: framesRemaining, framesPerMinute: framesPerMinute) else {
            return "ETA learning local pace"
        }
        return "~\(duration) at local pace"
    }

    private static func duration(framesRemaining: UInt64, framesPerMinute: Double?) -> String? {
        guard let framesPerMinute, framesPerMinute > 0.05 else { return nil }

        let seconds = Double(framesRemaining) / framesPerMinute * 60
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = seconds >= 3_600 ? [.hour, .minute] : [.minute]
        formatter.maximumUnitCount = 2
        return formatter.string(from: seconds)
    }
}
