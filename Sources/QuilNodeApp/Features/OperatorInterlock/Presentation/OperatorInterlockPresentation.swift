import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

/// Routes operator requests to immutable presentation models. Concrete copy
/// lives beside the lifecycle, update, firewall, or exit decision it explains.
enum OperatorInterlockPresentation {
    static func lifecycle(_ action: NodeLifecycleAction) -> OperatorInterlockModel {
        switch action {
        case .start: startNode
        case .restart: restartNode
        case .stop: stopNode
        }
    }

    static func diagnostic(_ repair: NodeDiagnosticRepair) -> OperatorInterlockModel {
        switch repair {
        case .restartNode:
            restartNode.reidentified(
                as: "diagnostic-restart",
                eyebrow: "DIAGNOSTIC REPAIR",
                outcome: "Restart the managed process, then rerun local checks against fresh evidence."
            )
        case .configureFirewall:
            firewallRepair
        default:
            restartNode.reidentified(
                as: "diagnostic-\(repair.rawValue)",
                eyebrow: "DIAGNOSTIC REPAIR",
                outcome: "Run the scoped local repair, then refresh diagnostics against new evidence."
            )
        }
    }
}

private extension OperatorInterlockModel {
    func reidentified(as id: String, eyebrow: String, outcome: String) -> OperatorInterlockModel {
        OperatorInterlockModel(
            id: id,
            eyebrow: eyebrow,
            title: title,
            outcome: outcome,
            symbol: symbol,
            tone: tone,
            steps: steps,
            changes: changes,
            preserved: preserved,
            verification: verification,
            trustNote: trustNote,
            decisions: decisions,
            defaultDecisionID: defaultDecisionID,
            cancelTitle: cancelTitle
        )
    }
}
