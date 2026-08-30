import SwiftUI

/// Keeps theme, appearance, and privacy controls visually consistent in both
/// rail widths without coupling them to navigation state.
struct DashboardSidebarUtilities: View {
    @Environment(\.quilTheme) private var theme
    @EnvironmentObject private var privacyMode: PrivacyModeController
    let isCollapsed: Bool
    let railInset: CGFloat

    @ViewBuilder
    var body: some View {
        if isCollapsed {
            compactControls
        } else {
            expandedControls
        }
    }

    private var compactControls: some View {
        VStack(spacing: 0) {
            ThemePickerButton(
                compact: true,
                controlHeight: 40,
                popoverEdge: .trailing,
                embedded: true
            )
            divider(width: 22)
            ThemeAppearanceControl(compact: true, embedded: true)
            divider(width: 22)
            PrivacyModeButton(
                isEnabled: $privacyMode.isEnabled,
                compact: true,
                controlHeight: 40,
                embedded: true
            )
        }
        .frame(width: 40)
        .background(surface)
        .overlay(border)
        .frame(maxWidth: .infinity, alignment: .center)
        .sidebarSection(inset: railInset)
    }

    private var expandedControls: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("DISPLAY")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(theme.colors.secondaryText.opacity(0.78))
                .padding(.leading, 2)

            VStack(spacing: 0) {
                ThemePickerButton(
                    compact: false,
                    fillsWidth: true,
                    controlHeight: 44,
                    popoverEdge: .trailing,
                    embedded: true,
                    showChevron: true
                )
                divider()
                ThemeAppearanceControl(compact: false, embedded: true)
                divider()
                PrivacyModeButton(
                    isEnabled: $privacyMode.isEnabled,
                    compact: false,
                    fillsWidth: true,
                    controlHeight: 44,
                    embedded: true
                )
            }
            .background(surface)
            .overlay(border)
        }
        .sidebarSection(inset: railInset)
    }

    private func divider(width: CGFloat? = nil) -> some View {
        Rectangle()
            .fill(theme.colors.border.opacity(0.42))
            .frame(width: width, height: max(theme.metrics.borderWidth, 0.5))
            .frame(maxWidth: width == nil ? .infinity : nil)
            .accessibilityHidden(true)
    }

    private var surface: some View {
        RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous)
            .fill(theme.colors.surfaceElevated.opacity(0.78))
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous)
            .strokeBorder(theme.colors.border.opacity(0.5), lineWidth: max(theme.metrics.borderWidth, 0.5))
            .allowsHitTesting(false)
    }
}
