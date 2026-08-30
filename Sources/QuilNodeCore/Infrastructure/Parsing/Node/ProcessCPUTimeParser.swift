import Foundation

/// Parses the cumulative CPU time formats emitted by macOS `ps`, including
/// `MM:SS.hh`, `HH:MM:SS.hh`, and the optional `DD-` prefix.
public enum ProcessCPUTimeParser {
    public static func parse(_ value: String) -> Double? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let dayParts = trimmed.split(separator: "-", maxSplits: 1)
        let days: Double
        let clock: Substring
        if dayParts.count == 2 {
            guard let parsedDays = Double(dayParts[0]) else { return nil }
            days = parsedDays
            clock = dayParts[1]
        } else {
            days = 0
            clock = dayParts[0]
        }

        let fields = clock.split(separator: ":")
        guard (2...3).contains(fields.count),
            let seconds = Double(fields[fields.count - 1]),
            let minutes = Double(fields[fields.count - 2])
        else { return nil }
        let hours = fields.count == 3 ? Double(fields[0]) : 0
        guard let hours else { return nil }
        return days * 86_400 + hours * 3_600 + minutes * 60 + seconds
    }
}
