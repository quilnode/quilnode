import Foundation

public enum NodeMetricsParser {
    public static func value(_ metric: String, in text: String) -> Double? {
        for rawLine in text.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.hasPrefix("#") else { continue }
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard fields.count == 2 else { continue }
            let name = fields[0].split(separator: "{").first.map(String.init) ?? ""
            if name == metric { return Double(fields[1]) }
        }
        return nil
    }

    /// Reads one Prometheus sample while requiring an exact label match.
    /// This avoids conflating inbound and outbound counters that share a
    /// metric name.
    public static func value(
        _ metric: String,
        labels requiredLabels: [String: String],
        in text: String
    ) -> Double? {
        for rawLine in text.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.hasPrefix("#") else { continue }
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard fields.count == 2, let sample = Double(fields[1]) else { continue }

            let descriptor = String(fields[0])
            let name = descriptor.split(separator: "{").first.map(String.init) ?? ""
            guard name == metric else { continue }
            let labels = parseLabels(in: descriptor)
            if requiredLabels.allSatisfy({ labels[$0.key] == $0.value }) {
                return sample
            }
        }
        return nil
    }

    private static func parseLabels(in descriptor: String) -> [String: String] {
        guard let opening = descriptor.firstIndex(of: "{"),
            let closing = descriptor.lastIndex(of: "}"),
            opening < closing
        else { return [:] }

        return descriptor[descriptor.index(after: opening)..<closing]
            .split(separator: ",")
            .reduce(into: [:]) { result, pair in
                let pieces = pair.split(separator: "=", maxSplits: 1)
                guard pieces.count == 2 else { return }
                let key = pieces[0].trimmingCharacters(in: .whitespaces)
                let value = pieces[1]
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                result[key] = value
            }
    }
}
