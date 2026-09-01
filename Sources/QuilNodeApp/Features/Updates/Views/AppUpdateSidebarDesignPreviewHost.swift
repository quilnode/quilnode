import SwiftUI

#if DEBUG
    /// Fixed update states rendered alongside the real display controls. This
    /// catches rail alignment and density regressions without network access.
    struct AppUpdateSidebarDesignPreviewHost: View {
        @StateObject private var privacyMode = PrivacyModeController()
        @StateObject private var themeController = ThemeController()

        var body: some View {
            HStack(alignment: .center, spacing: 44) {
                previewRail(isCollapsed: true)
                previewRail(isCollapsed: false)
            }
            .padding(44)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { ThemeCanvasBackground() }
            .environmentObject(privacyMode)
            .environmentObject(themeController)
        }

        private func previewRail(isCollapsed: Bool) -> some View {
            let theme = themeController.selectedTheme
            let width =
                isCollapsed
                ? theme.metrics.sidebarCollapsedWidth
                : theme.metrics.sidebarExpandedWidth
            let railInset = max(8, (theme.metrics.sidebarCollapsedWidth - 40) / 2)
            let presentation = AppUpdateSidebarPresentation(
                phase: .updateAvailable(version: "0.1.0-alpha.3"),
                availableVersion: "0.1.0-alpha.3",
                canCheck: true
            )!

            return VStack(alignment: .leading, spacing: 10) {
                Spacer(minLength: 0)
                AppUpdateSidebarControl(
                    presentation: presentation,
                    isCollapsed: isCollapsed,
                    railInset: railInset,
                    action: {}
                )
                DashboardSidebarUtilities(isCollapsed: isCollapsed, railInset: railInset)
            }
            .frame(width: width, height: 360)
            .padding(.vertical, 18)
            .background(theme.colors.sidebar)
            .clipShape(
                RoundedRectangle(
                    cornerRadius: theme.metrics.heroCornerRadius,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: theme.metrics.heroCornerRadius,
                    style: .continuous
                )
                .strokeBorder(theme.colors.border, lineWidth: 1)
            }
        }
    }
#endif
