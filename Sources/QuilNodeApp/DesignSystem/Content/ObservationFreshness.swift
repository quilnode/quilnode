import Foundation

/// An observation's own clock, never the refresh time of its containing view.
struct ObservationFreshness {
    let observedAt: Date?
    var now: Date = Date()
    var maximumAge: TimeInterval = 120

    var isCurrent: Bool {
        guard let observedAt else { return false }
        let age = now.timeIntervalSince(observedAt)
        return age >= -5 && age <= maximumAge
    }

    var label: String {
        guard let observedAt else { return "Not yet observed" }
        let age = now.timeIntervalSince(observedAt)
        guard age.isFinite, age < Double(Int.max), age >= -5 else { return "Observation clock mismatch" }
        let seconds = max(Int(age), 0)
        let elapsed: String
        if seconds < 5 {
            elapsed = "just now"
        } else if seconds < 60 {
            elapsed = "\(seconds)s ago"
        } else if seconds < 3_600 {
            elapsed = "\(seconds / 60)m ago"
        } else if seconds < 86_400 {
            elapsed = "\(seconds / 3_600)h ago"
        } else {
            elapsed = "\(seconds / 86_400)d ago"
        }
        return (isCurrent ? "Read " : "Last read ") + elapsed
    }
}
