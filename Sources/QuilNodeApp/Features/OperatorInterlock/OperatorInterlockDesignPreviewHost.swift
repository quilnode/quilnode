import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

enum OperatorInterlockPreviewMode: String {
    case restart
    case firewall
    case updates
    case quit
}

struct OperatorInterlockDesignPreviewHost: View {
    let mode: OperatorInterlockPreviewMode

    var body: some View {
        OperatorInterlockView(
            model: model,
            onCancel: {},
            onConfirm: { _ in }
        )
    }

    private var model: OperatorInterlockModel {
        switch mode {
        case .restart:
            OperatorInterlockPresentation.lifecycle(.restart)
        case .firewall:
            OperatorInterlockPresentation.diagnostic(.configureFirewall)
        case .updates:
            OperatorInterlockPresentation.updatePolicy(.approvedDevelopment)
        case .quit:
            OperatorInterlockPresentation.quitDuringUpdate
        }
    }
}
