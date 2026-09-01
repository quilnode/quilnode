import SwiftUI

/// Theme-aware rendering for the persistent update action. Keeping framework
/// state outside this view makes every visual phase deterministic to preview.
struct AppUpdateSidebarControl: View {
    @Environment(\.quilTheme) private var theme
    @State private var isHovered = false

    let presentation: AppUpdateSidebarPresentation
    let isCollapsed: Bool
    let railInset: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isCollapsed {
                compactLabel
            } else {
                expandedLabel
            }
        }
        .buttonStyle(QuilPressFeedbackButtonStyle(pressedOpacity: 0.88, pressedScale: 0.985))
        .disabled(!presentation.isEnabled)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .help(accessibilityLabel)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(
            presentation.isEnabled
                ? "Opens the verified QuilNode updater" : "Update preparation is in progress"
        )
        .accessibilityIdentifier("quilnode-app-update-action")
        .sidebarSection(inset: railInset)
        .transition(.opacity)
    }

    private var compactLabel: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: presentation.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)

            if presentation.showsProgress {
                ProgressView()
                    .controlSize(.mini)
                    .tint(tint)
                    .frame(width: 13, height: 13)
                    .background(theme.colors.sidebar, in: Circle())
                    .offset(x: 3, y: -3)
            } else {
                Circle()
                    .fill(tint)
                    .frame(width: 7, height: 7)
                    .overlay(Circle().stroke(theme.colors.sidebar, lineWidth: 2))
                    .offset(x: 1, y: -1)
            }
        }
        .frame(width: 40, height: 40)
        .background(surface)
        .overlay(border)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var expandedLabel: some View {
        HStack(spacing: 10) {
            Image(systemName: presentation.systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(presentation.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.colors.primaryText)
                    .lineLimit(1)
                Text(presentation.detail)
                    .font(.caption2)
                    .foregroundStyle(theme.colors.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if presentation.showsProgress {
                ProgressView()
                    .controlSize(.small)
                    .tint(tint)
            } else {
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(tint.opacity(0.82))
            }
        }
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(surface)
        .overlay(border)
    }

    private var tint: Color {
        switch presentation.tone {
        case .available: theme.colors.accent
        case .progress: theme.colors.info
        case .failure: theme.colors.danger
        }
    }

    private var surface: some View {
        RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous)
            .fill(tint.opacity(isHovered ? 0.16 : 0.10))
    }

    private var border: some View {
        RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous)
            .strokeBorder(
                tint.opacity(isHovered ? 0.55 : 0.34),
                lineWidth: max(theme.metrics.borderWidth, 0.5)
            )
            .allowsHitTesting(false)
    }

    private var accessibilityLabel: String {
        "\(presentation.title), \(presentation.detail)"
    }
}
