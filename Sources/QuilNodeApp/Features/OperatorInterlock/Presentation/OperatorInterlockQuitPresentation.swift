import Foundation

extension OperatorInterlockPresentation {
    static let quitDuringUpdate = OperatorInterlockModel(
        id: "quit-during-update",
        eyebrow: "ACTIVE UPDATE",
        title: "An update is still running",
        outcome: "QuilNode can finish the preparation with every dashboard window closed.",
        symbol: "exclamationmark.arrow.triangle.2.circlepath",
        tone: .warning,
        steps: [
            .init(
                id: "interrupt", title: "Interrupt work",
                detail: "Stop the current download or build before activation.",
                symbol: "pause.fill", tone: .warning
            ),
            .init(
                id: "close", title: "Close QuilNode",
                detail: "End monitoring and the current update session.",
                symbol: "xmark.app.fill", tone: .warning
            ),
            .init(
                id: "retain", title: "Keep current node",
                detail: "Leave the installed runtime and service state unchanged.",
                symbol: "checkmark.shield.fill", tone: .success
            ),
        ],
        changes: [
            .init(
                id: "update-session", title: "Current update session",
                detail: "The in-progress preparation is interrupted and can be started again later.",
                symbol: "hammer.fill"
            )
        ],
        preserved: standardNodeBoundary + [
            .init(
                id: "service-state", title: "Node service state",
                detail: "Quitting the controller does not stop or restart the managed node.",
                symbol: "power.circle.fill"
            )
        ],
        verification: ["Installed node retained", "Service command not sent", "Key material untouched"],
        trustNote: "Keep Running is safest: the update continues in the background without a dashboard window.",
        decisions: [
            .init(
                id: "quit", title: "Quit anyway",
                detail: "Interrupt only the current QuilNode update session.",
                actionTitle: "Quit anyway", symbol: "xmark.app.fill",
                tone: .destructive, bullets: []
            )
        ],
        defaultDecisionID: "quit",
        cancelTitle: "Keep Running"
    )
}
