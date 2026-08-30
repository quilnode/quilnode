import SwiftUI

struct AppUpdateDashboardCard: View {
    @EnvironmentObject private var appUpdates: AppUpdateController
    @Environment(\.quilTheme) private var theme

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            DashboardCircleIcon(systemImage: icon, tint: tint, size: 42)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text("QuilNode app")
                        .font(.subheadline.weight(.semibold))
                    Text("v\(appUpdates.currentVersion) (\(appUpdates.currentBuild))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Text(appUpdates.phase.title)
                    .font(.caption.weight(.semibold))
                Text(appUpdates.phase.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 6) {
                Button {
                    appUpdates.checkNow()
                } label: {
                    if appUpdates.phase == .checking {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Check app", systemImage: "sparkles")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!appUpdates.canCheck || appUpdates.phase == .checking)

                Text(appUpdates.automaticallyChecks ? "Daily checks on" : "Manual checks")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .controlSurface(tint: tint)
        .accessibilityElement(children: .contain)
    }

    private var tint: Color {
        switch appUpdates.phase {
        case .failed: theme.colors.danger
        case .updateAvailable: theme.colors.warning
        case .current: theme.colors.success
        default: theme.colors.accent
        }
    }

    private var icon: String {
        switch appUpdates.phase {
        case .failed: "exclamationmark.triangle.fill"
        case .updateAvailable: "arrow.down.app.fill"
        case .current: "checkmark.seal.fill"
        case .checking: "arrow.triangle.2.circlepath"
        case .ready: "app.badge.checkmark"
        }
    }
}
