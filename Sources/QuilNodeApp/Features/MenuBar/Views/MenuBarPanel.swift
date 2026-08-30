import AppKit
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

/// App-environment adapter for the pure menu-bar content.
///
/// Keeping navigation and coordinators here leaves `MenuBarContent` fully
/// deterministic for screenshots, accessibility review, and presentation QA.
struct MenuBarPanel: View {
    @EnvironmentObject private var monitor: NodeMonitor
    @EnvironmentObject private var releaseChecker: ReleaseChecker
    @EnvironmentObject private var privacyMode: PrivacyModeController
    @EnvironmentObject private var commandCenter: DashboardCommandCenter

    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        MenuBarContent(
            snapshot: monitor.snapshot,
            phase: monitor.observationPhase,
            milestones: releaseChecker.protocolMilestones,
            isRefreshing: monitor.isRefreshing,
            privacyEnabled: privacyMode.isEnabled,
            onOpenDashboard: { openDashboard($0) },
            onRefresh: { Task { await monitor.refresh(forceNodeInfo: true) } },
            onTogglePrivacy: { privacyMode.toggle() },
            onOpenSettings: openSettingsWindow,
            onQuit: { NSApp.terminate(nil) }
        )
    }

    private func openSettingsWindow() {
        dismiss()
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
    }

    private func openDashboard(_ destination: DashboardDestination) {
        dismiss()
        DispatchQueue.main.async {
            DashboardWindowPresenter.present(using: openWindow)
            commandCenter.send(.select(destination))
        }
    }
}
