import SwiftUI

/// Durable preferences for the QuilNode application update channel. Quilibrium
/// runtime updates intentionally stay in the dashboard Update Center because
/// they affect a running node and require task-specific context.
struct AppUpdateSettingsPane: View {
    @EnvironmentObject private var appUpdates: AppUpdateController
    @Environment(\.quilTheme) private var theme

    var body: some View {
        SettingsPaneContainer {
            updateStatus

            SettingsCard {
                SettingsPreferenceRow(
                    systemImage: "shippingbox.fill",
                    title: "Installed version",
                    detail: "The QuilNode application currently running on this Mac."
                ) {
                    SettingsValueLabel(text: "\(appUpdates.currentVersion) (\(appUpdates.currentBuild))")
                }

                SettingsDivider()

                SettingsPreferenceRow(
                    systemImage: "clock.arrow.circlepath",
                    title: "Last attempt",
                    detail: checkFreshnessDetail
                ) {
                    Button {
                        appUpdates.checkNow()
                    } label: {
                        if appUpdates.phase == .checking {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Check Now")
                        }
                    }
                    .disabled(!appUpdates.canCheck || appUpdates.phase == .checking)
                }

                SettingsDivider()

                SettingsPreferenceRow(
                    systemImage: "calendar.badge.clock",
                    title: "Automatic check",
                    detail:
                        "Discover signed releases once per day. An update button appears in the sidebar when action is needed."
                ) {
                    Toggle(
                        "Daily",
                        isOn: Binding(
                            get: { appUpdates.automaticallyChecks },
                            set: { appUpdates.setAutomaticallyChecks($0) }
                        )
                    )
                    .toggleStyle(.switch)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                SettingsSectionHeader(title: "Update trust path", trailing: "Before installation")
                SettingsCard {
                    AppUpdateTrustRow(
                        systemImage: "checkmark.shield.fill",
                        title: "Signed release feed",
                        detail: "A project Ed25519 key authenticates release metadata before QuilNode offers it.",
                        state: "Pinned key",
                        tint: theme.colors.success
                    )
                    SettingsDivider()
                    AppUpdateTrustRow(
                        systemImage: "archivebox.fill",
                        title: "Archive and code signature",
                        detail:
                            "The archive is verified before extraction, then the application code signature is checked.",
                        state: "Verified first",
                        tint: theme.colors.accent
                    )
                    SettingsDivider()
                    AppUpdateTrustRow(
                        systemImage: "hand.raised.fill",
                        title: "Installation requires approval",
                        detail:
                            "Release notes and the install prompt remain visible. No application update installs silently.",
                        state: "Ask to install",
                        tint: theme.colors.warning
                    )
                }
            }

            SettingsFooterNote(
                systemImage: "point.3.connected.trianglepath.dotted",
                text: "QuilNode app updates are independent from Quilibrium node releases and do not stop proving."
            )
        }
    }

    private var updateStatus: some View {
        HStack(alignment: .center, spacing: 14) {
            DashboardCircleIcon(systemImage: statusIcon, tint: statusTint, size: 42)
            VStack(alignment: .leading, spacing: 3) {
                Text("QuilNode app updates")
                    .font(.headline)
                Text(appUpdates.phase.detail)
                    .font(.caption)
                    .foregroundStyle(theme.colors.secondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 12)
            SettingsStatusPill(title: appUpdates.phase.title, tint: statusTint)
        }
        .padding(16)
        .controlSurface(tint: statusTint)
    }

    private var checkFreshnessDetail: String {
        guard let checkedAt = appUpdates.lastAttemptAt else {
            return "No application update check has been attempted yet."
        }
        return
            "Attempted \(checkedAt.formatted(.relative(presentation: .named))). Check the status above for the result."
    }

    private var statusTint: Color {
        switch appUpdates.phase {
        case .failed: theme.colors.danger
        case .updateAvailable, .unavailable: theme.colors.warning
        case .current: theme.colors.success
        default: theme.colors.accent
        }
    }

    private var statusIcon: String {
        switch appUpdates.phase {
        case .failed: "exclamationmark.triangle.fill"
        case .updateAvailable: "arrow.down.app.fill"
        case .current: "checkmark.seal.fill"
        case .unavailable: "info.circle"
        case .checking: "arrow.triangle.2.circlepath"
        case .downloading: "arrow.down.circle"
        case .preparing: "checkmark.shield"
        case .installing: "shippingbox"
        case .ready: "app.badge.checkmark"
        }
    }
}

private struct AppUpdateTrustRow: View {
    @Environment(\.quilTheme) private var theme

    let systemImage: String
    let title: String
    let detail: String
    let state: String
    let tint: Color

    var body: some View {
        HStack(alignment: .center, spacing: 13) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(theme.colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 14)
            SettingsStatusPill(title: state, tint: tint)
        }
        .frame(minHeight: 48)
        .accessibilityElement(children: .combine)
    }
}
