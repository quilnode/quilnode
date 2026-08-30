import Foundation

public enum WorkerRuntimeParser {
    /// `.25` local mode reports thread workers with `core_id` in its own log.
    /// Returning the highest observed core id is robust to line ordering and
    /// avoids relying on a private config file.
    public static func localThreadWorkerCount(in text: String) -> Int? {
        var maximum: Int?
        let pattern = #"quil_engine/src/thread_worker\.rs.*\"core_id\":([0-9]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        regex.enumerateMatches(in: text, range: range) { match, _, _ in
            guard let match,
                let valueRange = Range(match.range(at: 1), in: text),
                let value = Int(text[valueRange])
            else { return }
            maximum = max(maximum ?? 0, value)
        }
        return maximum
    }
}
