import Foundation

public enum NodeProcessUptimeParser {
    /// Parses macOS `ps etime` values: `MM:SS`, `HH:MM:SS`, or
    /// `DD-HH:MM:SS`.
    public static func seconds(from value: String?) -> TimeInterval? {
        guard let value, !value.isEmpty else { return nil }
        let dayParts = value.split(separator: "-", maxSplits: 1)
        let dayCount: Int
        let clock: Substring
        if dayParts.count == 2 {
            dayCount = Int(dayParts[0]) ?? 0
            clock = dayParts[1]
        } else {
            dayCount = 0
            clock = dayParts[0]
        }
        let components = clock.split(separator: ":").compactMap { Int($0) }
        guard components.count == 2 || components.count == 3 else { return nil }
        let hours = components.count == 3 ? components[0] : 0
        let minutes = components[components.count - 2]
        let seconds = components[components.count - 1]
        return TimeInterval((((dayCount * 24) + hours) * 60 + minutes) * 60 + seconds)
    }
}
