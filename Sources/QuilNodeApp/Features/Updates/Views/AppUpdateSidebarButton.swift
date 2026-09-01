import SwiftUI

/// Persistent, state-driven entry point for a confirmed QuilNode app update.
/// It deliberately stays out of the rail during routine background checks.
struct AppUpdateSidebarButton: View {
    @EnvironmentObject private var appUpdates: AppUpdateController

    let isCollapsed: Bool
    let railInset: CGFloat

    private var presentation: AppUpdateSidebarPresentation? {
        AppUpdateSidebarPresentation(
            phase: appUpdates.phase,
            availableVersion: appUpdates.availableVersion,
            canCheck: appUpdates.canCheck
        )
    }

    @ViewBuilder
    var body: some View {
        if let presentation {
            AppUpdateSidebarControl(
                presentation: presentation,
                isCollapsed: isCollapsed,
                railInset: railInset,
                action: appUpdates.installAvailableUpdate
            )
        }
    }
}
