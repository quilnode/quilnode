import Foundation

struct BuildLogSnapshot: Equatable, Sendable {
    let output: String
    let visibleLineCount: Int
    let wasTrimmed: Bool
    let warningCount: Int
    let errorCount: Int
    let latestEvent: String
    let observedAt: Date?

    static let waiting = BuildLogSnapshot(
        output: "",
        visibleLineCount: 0,
        wasTrimmed: false,
        warningCount: 0,
        errorCount: 0,
        latestEvent: "Waiting for output",
        observedAt: nil
    )

    static let unavailable = BuildLogSnapshot(
        output: "",
        visibleLineCount: 0,
        wasTrimmed: false,
        warningCount: 0,
        errorCount: 0,
        latestEvent: "Output unavailable",
        observedAt: nil
    )

    var hasOutput: Bool { !output.isEmpty }
    var displayOutput: String { hasOutput ? output : "Waiting for build output…" }
    var activityDetail: String {
        if !hasOutput { return "Listening locally" }
        return wasTrimmed ? "Bounded log tail" : "Local log tail"
    }

    func hasSameEvidence(as other: BuildLogSnapshot) -> Bool {
        output == other.output
            && visibleLineCount == other.visibleLineCount
            && wasTrimmed == other.wasTrimmed
            && warningCount == other.warningCount
            && errorCount == other.errorCount
            && latestEvent == other.latestEvent
    }

    static func parse(
        _ text: String,
        reachedByteLimit: Bool = false,
        observedAt: Date = Date()
    ) -> BuildLogSnapshot {
        let maximumLines = 320
        var allLines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if text.last?.isNewline == true, allLines.last?.isEmpty == true {
            allLines.removeLast()
        }
        let visibleLines = Array(allLines.suffix(maximumLines))
        let output = visibleLines.joined(separator: "\n")
        let meaningful = visibleLines.reversed().first { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let warnings = visibleLines.count { diagnosticKind(for: $0) == .warning }
        let errors = visibleLines.count { diagnosticKind(for: $0) == .error }

        return BuildLogSnapshot(
            output: output,
            visibleLineCount: text.isEmpty ? 0 : visibleLines.count,
            wasTrimmed: reachedByteLimit || allLines.count > maximumLines,
            warningCount: warnings,
            errorCount: errors,
            latestEvent: meaningful.map(compactEvent) ?? "Waiting for output",
            observedAt: text.isEmpty ? nil : observedAt
        )
    }

    private enum DiagnosticKind { case warning, error }

    private static func diagnosticKind(for line: String) -> DiagnosticKind? {
        let normalized = line.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.contains("warning:") { return .warning }
        if normalized.contains("error:") || normalized.contains("fatal error:") { return .error }
        return nil
    }

    private static func compactEvent(_ line: String) -> String {
        let normalized = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > 110 else { return normalized }
        return String(normalized.prefix(107)) + "…"
    }
}
