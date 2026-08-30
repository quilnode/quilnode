import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

enum DiagnosticVisuals {
    static func tint(_ state: NodeDiagnosticState, theme: QuilTheme) -> Color {
        switch state {
        case .checking, .waiting: theme.colors.info
        case .passed: theme.colors.success
        case .advisory: theme.colors.warning
        case .failed: theme.colors.danger
        }
    }

    static func icon(_ state: NodeDiagnosticState) -> String {
        switch state {
        case .checking: "ellipsis.circle"
        case .passed: "checkmark.circle.fill"
        case .waiting: "hourglass.circle.fill"
        case .advisory: "exclamationmark.circle.fill"
        case .failed: "xmark.octagon.fill"
        }
    }

    static func stateLabel(_ state: NodeDiagnosticState) -> String {
        switch state {
        case .checking: "CHECKING"
        case .passed: "PASS"
        case .waiting: "WAITING"
        case .advisory: "REVIEW"
        case .failed: "ACTION"
        }
    }
}
