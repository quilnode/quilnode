import Foundation

enum RuntimeResourceFormatter {
    static func memory(_ mebibytes: Double?) -> String {
        guard let mebibytes, mebibytes.isFinite, mebibytes >= 0 else { return "—" }
        return String(format: "%.1f GiB", locale: Locale.current, mebibytes / 1024)
    }

    /// `ps etime`: [[days-]hours:]minutes:seconds, not an availability score.
    static func uptime(_ elapsed: String?) -> String {
        guard let elapsed else { return "—" }
        let dayParts = elapsed.split(separator: "-", omittingEmptySubsequences: false)
        guard dayParts.count <= 2, let clock = dayParts.last else { return "—" }
        let days = dayParts.count == 2 ? Int(dayParts[0]) : 0
        let parts = clock.split(separator: ":", omittingEmptySubsequences: false)
        guard let days, days >= 0, parts.count == 2 || parts.count == 3 else { return "—" }
        let values = parts.compactMap { Int($0) }
        guard values.count == parts.count, values.allSatisfy({ $0 >= 0 }),
            let seconds = values.last, seconds < 60
        else { return "—" }
        let minutes = values[values.count - 2]
        let hours = values.count == 3 ? values[0] : 0
        guard minutes < 60, hours < 24 else { return "—" }
        if days > 0 { return "\(days)d \(hours)h \(minutes)m" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m \(seconds)s"
    }
}
