import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct DiagnosticCategoryPresentation: Identifiable, Sendable {
    var id: NodeDiagnosticCategory { category }
    var category: NodeDiagnosticCategory
    var checks: [NodeDiagnosticCheck]

    var passedCount: Int { checks.filter { $0.state == .passed }.count }
    var waitingCount: Int { checks.filter { $0.state == .waiting }.count }
    var reviewCount: Int { checks.filter { $0.state == .advisory }.count }
    var failedCount: Int { checks.filter { $0.state == .failed }.count }

    static func make(report: NodeDiagnosticReport) -> [Self] {
        NodeDiagnosticCategory.allCases.map { category in
            Self(category: category, checks: report.checks.filter { $0.category == category })
        }
    }
}

struct DiagnosticsPresentation: Sendable {
    var categories: [DiagnosticCategoryPresentation]
    var findings: [NodeDiagnosticCheck]
    var passedCount: Int
    var waitingCount: Int
    var reviewCount: Int
    var failedCount: Int

    var selectedFallbackID: String? { findings.first?.id ?? categories.flatMap(\.checks).first?.id }

    static func make(report: NodeDiagnosticReport) -> Self {
        let findings = report.checks
            .filter { $0.state != .passed && $0.state != .checking }
            .sorted { left, right in
                if left.state.rank != right.state.rank { return left.state.rank > right.state.rank }
                return left.title < right.title
            }
        return Self(
            categories: DiagnosticCategoryPresentation.make(report: report),
            findings: findings,
            passedCount: report.passedCount,
            waitingCount: report.waitingCount,
            reviewCount: report.checks.filter { $0.state == .advisory }.count,
            failedCount: report.checks.filter { $0.state == .failed }.count
        )
    }
}

enum DiagnosticRepairPresentation {
    static func label(_ repair: NodeDiagnosticRepair) -> String {
        switch repair {
        case .refreshEvidence: "Run again"
        case .startNode: "Start node"
        case .restartNode: "Restart node"
        case .openNetwork: "Open Network"
        case .configureFirewall: "Configure firewall"
        case .openUpdates: "Open Updates"
        case .repairQClient: "Repair qclient"
        }
    }

    static func icon(_ repair: NodeDiagnosticRepair) -> String {
        switch repair {
        case .refreshEvidence: "arrow.clockwise"
        case .startNode: "play.fill"
        case .restartNode: "arrow.clockwise"
        case .openNetwork: "network"
        case .configureFirewall: "shield.lefthalf.filled"
        case .openUpdates: "arrow.triangle.2.circlepath"
        case .repairQClient: "wrench.and.screwdriver"
        }
    }

    static func scope(_ repair: NodeDiagnosticRepair?) -> String {
        switch repair {
        case nil: "Observation only; no repair is proposed."
        case .refreshEvidence: "Refreshes read-only local evidence."
        case .startNode: "Starts only the managed Quilibrium node service."
        case .restartNode: "Briefly restarts only the managed node runtime."
        case .openNetwork: "Navigates to Network; no setting changes here."
        case .configureFirewall: "Applies the minimum QuilNode rule to macOS Firewall."
        case .openUpdates: "Navigates to Updates; nothing installs automatically."
        case .repairQClient: "Installs or replaces only the managed qclient tool."
        }
    }

    static func safety(_ repair: NodeDiagnosticRepair?) -> String {
        switch repair {
        case .restartNode, .configureFirewall: "Requires confirmation"
        case .startNode, .repairQClient: "Explicit action"
        default: "Read-only or navigation"
        }
    }
}
