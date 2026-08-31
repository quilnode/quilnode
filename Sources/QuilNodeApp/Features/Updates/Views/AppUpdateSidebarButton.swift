import SwiftUI

/// Persistent, state-driven entry point for a confirmed QuilNode app update.
/// It deliberately stays out of the rail during routine background checks.
struct AppUpdateSidebarButton: View {
    @Environment(\.quilTheme) private var theme
    @EnvironmentObject private var appUpdates: AppUpdateController
    @State private var isHovered = false

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
            Button {
                appUpdates.installAvailableUpdate()
            } label: {
                if isCollapsed {
                    compactLabel(presentation)
                } else {
                    expandedLabel(presentation)
                }
            }
            .buttonStyle(QuilPressFeedbackButtonStyle(pressedOpacity: 0.88, pressedScale: 0.985))
            .disabled(!presentation.isEnabled)
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
            .help(accessibilityLabel(presentation))
            .accessibilityLabel(accessibilityLabel(presentation))
            .accessibilityHint(
                presentation.isEnabled ? "Opens the verified QuilNode updater" : "Update preparation is in progress"
            )
            .accessibilityIdentifier("quilnode-app-update-action")
            .sidebarSection(inset: railInset)
            .transition(.opacity)
        }
    }

    private func compactLabel(_ presentation: AppUpdateSidebarPresentation) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: presentation.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint(presentation))
                .frame(width: 40, height: 40)

            if presentation.showsProgress {
                ProgressView()
                    .controlSize(.mini)
                    .tint(tint(presentation))
                    .frame(width: 13, height: 13)
                    .background(theme.colors.sidebar, in: Circle())
                    .offset(x: 3, y: -3)
            } else {
                Circle()
                    .fill(tint(presentation))
                    .frame(width: 7, height: 7)
                    .overlay(Circle().stroke(theme.colors.sidebar, lineWidth: 2))
                    .offset(x: 1, y: -1)
            }
        }
        .frame(width: 40, height: 40)
        .background(surface(presentation))
        .overlay(border(presentation))
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func expandedLabel(_ presentation: AppUpdateSidebarPresentation) -> some View {
        HStack(spacing: 10) {
            Image(systemName: presentation.systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint(presentation))
                .frame(width: 30, height: 30)
                .background(tint(presentation).opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

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
                    .tint(tint(presentation))
            } else {
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(tint(presentation).opacity(0.82))
            }
        }
        .padding(.horizontal, 9)
        .frame(maxWidth: .infinity, minHeight: 48)
        .background(surface(presentation))
        .overlay(border(presentation))
    }

    private func tint(_ presentation: AppUpdateSidebarPresentation) -> Color {
        switch presentation.tone {
        case .available: theme.colors.accent
        case .progress: theme.colors.info
        case .failure: theme.colors.danger
        }
    }

    private func surface(_ presentation: AppUpdateSidebarPresentation) -> some View {
        RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous)
            .fill(tint(presentation).opacity(isHovered ? 0.16 : 0.10))
    }

    private func border(_ presentation: AppUpdateSidebarPresentation) -> some View {
        RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous)
            .strokeBorder(
                tint(presentation).opacity(isHovered ? 0.55 : 0.34),
                lineWidth: max(theme.metrics.borderWidth, 0.5)
            )
            .allowsHitTesting(false)
    }

    private func accessibilityLabel(_ presentation: AppUpdateSidebarPresentation) -> String {
        "\(presentation.title), \(presentation.detail)"
    }
}
