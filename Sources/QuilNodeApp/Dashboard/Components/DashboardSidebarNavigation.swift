import SwiftUI

/// Owns navigation selection and hover state for the dashboard rail.
struct DashboardSidebarNavigation: View {
    @Environment(\.quilTheme) private var theme
    @Environment(\.quilMotion) private var motion
    @State private var hoveredDestination: DashboardDestination?
    @Binding var destination: DashboardDestination
    let isCollapsed: Bool
    let railInset: CGFloat
    let accent: Color
    let onSelectDestination: (DashboardDestination) -> Void

    var body: some View {
        VStack(spacing: isCollapsed ? 6 : 4) {
            ForEach(DashboardDestination.allCases) { item in
                destinationButton(item)
            }
        }
        .sidebarSection(inset: railInset)
        .animation(motion.hover, value: hoveredDestination)
        .animation(motion.selection, value: destination)
    }

    private func destinationButton(_ item: DashboardDestination) -> some View {
        Button {
            destination = item
            onSelectDestination(item)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 13 * theme.components.iconScale, weight: .semibold))
                    .frame(width: 18)
                if !isCollapsed {
                    Text(item.title)
                        .font(.subheadline.weight(destination == item ? .semibold : .regular))
                    Spacer(minLength: 0)
                }
            }
            .foregroundStyle(
                destination == item
                    ? accent
                    : theme.colors.primaryText.opacity(hoveredDestination == item ? 0.94 : 0.76)
            )
            .padding(.horizontal, isCollapsed ? 0 : 11)
            .frame(
                maxWidth: .infinity,
                minHeight: isCollapsed
                    ? theme.metrics.navigationRowHeight
                    : max(36, theme.metrics.navigationRowHeight - 4)
            )
            .contentShape(Rectangle())
            .background { selectionBackground(for: item) }
        }
        .buttonStyle(QuilPressFeedbackButtonStyle(pressedOpacity: 0.88, pressedScale: 0.995))
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onHover { hovered in
            if hovered {
                hoveredDestination = item
            } else if hoveredDestination == item {
                hoveredDestination = nil
            }
        }
        .help(item.title)
        .accessibilityLabel(item.title)
    }

    @ViewBuilder
    private func selectionBackground(for item: DashboardDestination) -> some View {
        if destination == item {
            let shape = RoundedRectangle(
                cornerRadius: theme.components.navigationSelection == .capsule
                    ? theme.metrics.navigationRowHeight / 2
                    : theme.metrics.navigationCornerRadius,
                style: .continuous
            )
            switch theme.components.navigationSelection {
            case .row, .capsule:
                shape
                    .fill(theme.colors.selection.opacity(theme.components.selectionFillAlpha))
                    .overlay(
                        shape.strokeBorder(
                            accent.opacity(0.56), lineWidth: theme.components.selectedBorderWidth))
            case .icon:
                HStack {
                    RoundedRectangle(cornerRadius: theme.metrics.navigationCornerRadius, style: .continuous)
                        .fill(theme.colors.selection.opacity(theme.components.selectionFillAlpha))
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.metrics.navigationCornerRadius, style: .continuous)
                                .strokeBorder(
                                    accent.opacity(0.58), lineWidth: theme.components.selectedBorderWidth)
                        )
                        .frame(width: 40)
                    Spacer(minLength: 0)
                }
            }
        } else if hoveredDestination == item {
            RoundedRectangle(
                cornerRadius: theme.metrics.navigationCornerRadius,
                style: .continuous
            )
            .fill(theme.colors.selection.opacity(0.32))
        }
    }
}
