import Foundation

extension NodeDiagnosticEvaluator {
    static func check(
        id: String,
        category: NodeDiagnosticCategory,
        state: NodeDiagnosticState,
        title: String,
        summary: String,
        evidence: String,
        observedAt: Date? = nil,
        repair: NodeDiagnosticRepair? = nil
    ) -> NodeDiagnosticCheck {
        NodeDiagnosticCheck(
            id: id,
            category: category,
            state: state,
            title: title,
            summary: summary,
            evidence: evidence,
            observedAt: observedAt,
            repair: repair
        )
    }

    static func ageDescription(_ seconds: TimeInterval) -> String {
        if seconds < 60 { return "\(Int(seconds.rounded())) seconds" }
        if seconds < 3_600 { return "\(Int((seconds / 60).rounded())) minutes" }
        return "\(Int((seconds / 3_600).rounded())) hours"
    }
}
