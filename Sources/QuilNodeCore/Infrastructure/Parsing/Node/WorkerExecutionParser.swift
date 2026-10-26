import Foundation

enum WorkerExecutionParser {
    static func parse(_ line: String, readAt: Date) -> WorkerExecutionObservation? {
        guard line.hasPrefix("Local execution:"), line.count <= 16_384,
            let state = capture(#"^Local execution: ([a-z]+)"#, in: line)
        else { return nil }
        let known = [
            "start", "starting", "wait", "waiting", "sync", "syncing", "serve", "serving",
            "close", "closing", "handoff", "running", "blocked", "stopped", "unknown", "stale",
        ]
        let observationAge = capture(#"; observation ([0-9]+)s ago"#, in: line).flatMap(boundedAge)
        let advanceAge = capture(#"; last advance ([0-9]+)s ago"#, in: line).flatMap(boundedAge)
        return WorkerExecutionObservation(
            state: known.contains(state) ? state : "unknown",
            blocker: capture(#"^Local execution: [a-z]+ \(([^;]{1,512})\);"#, in: line),
            frame: capture(#"; height ([0-9]+);"#, in: line).flatMap(UInt64.init),
            lastAdvanceAt: advanceAge.map { readAt.addingTimeInterval(-$0) },
            observedAt: observationAge.map { readAt.addingTimeInterval(-$0) },
            readAt: readAt,
            recoveryPhase: capture(#"; Recovery: ([a-z_]+)"#, in: line),
            recoveryFailures: capture(#"\(([0-9]+) failed in a row\)"#, in: line).flatMap(Int.init),
            sealRecorded: line.contains("; Seal:") ? line.contains(", recorded by GLOBAL ") : nil
        )
    }

    private static func boundedAge(_ value: String) -> TimeInterval? {
        guard let seconds = UInt64(value), seconds <= 3_155_760_000 else { return nil }
        return TimeInterval(seconds)
    }

    private static func capture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
            let range = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[range])
    }
}
