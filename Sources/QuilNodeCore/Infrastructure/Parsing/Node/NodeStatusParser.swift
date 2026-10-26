import Foundation

public enum NodeStatusParser {
    public static func latestStatus(in text: String) -> [String: Any]? {
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true).reversed() {
            let line = String(rawLine)
            guard line.contains("node status"), let brace = line.firstIndex(of: "{") else {
                continue
            }
            let payload = String(line[brace...])
            guard
                let data = payload.data(using: .utf8),
                let object = try? JSONSerialization.jsonObject(with: data),
                let dictionary = object as? [String: Any]
            else {
                continue
            }
            return dictionary
        }
        return nil
    }

    public static func recentWarnings(in text: String, limit: Int = 5) -> [String] {
        let warningLines =
            text
            .split(separator: "\n", omittingEmptySubsequences: true)
            .lazy
            .map(String.init)
            .filter { $0.contains("\twarn\t") || $0.contains("\terror\t") }
            .suffix(max(0, limit))

        return warningLines.map(compactLogLine)
    }

    public static func uint64(_ dictionary: [String: Any], _ key: String, fallback: UInt64 = 0) -> UInt64 {
        if let value = dictionary[key] as? NSNumber { return value.uint64Value }
        if let value = dictionary[key] as? String { return UInt64(value) ?? fallback }
        return fallback
    }

    public static func int(_ dictionary: [String: Any], _ key: String, fallback: Int = 0) -> Int {
        if let value = dictionary[key] as? NSNumber { return value.intValue }
        if let value = dictionary[key] as? String { return Int(value) ?? fallback }
        return fallback
    }

    private static func compactLogLine(_ line: String) -> String {
        let parts = line.split(separator: "\t", omittingEmptySubsequences: true)
        if parts.count >= 4 {
            let timestamp = parts[0]
            let message = parts[3]
            let detail = parts.count >= 5 ? " \(parts[4])" : ""
            return "\(timestamp) — \(message)\(detail)"
        }
        return String(line.prefix(600))
    }
}
