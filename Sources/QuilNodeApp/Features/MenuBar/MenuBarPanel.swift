import AppKit
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

/// A glanceable, action-oriented companion to the full dashboard.
///
/// The panel deliberately avoids nested menus and popovers. Persistent choices
/// live in Settings; this surface answers current status and exposes only the
/// frequent actions an operator needs while another app is active.
struct MenuBarPanel: View {
    @EnvironmentObject private var monitor: NodeMonitor
    @EnvironmentObject private var services: NodeServices
    @EnvironmentObject private var releaseChecker: ReleaseChecker
    @EnvironmentObject private var privacyMode: PrivacyModeController
    @EnvironmentObject private var commandCenter: DashboardCommandCenter

    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.quilTheme) private var theme

    private var presentation: MenuBarPresentation {
        MenuBarPresentation(snapshot: monitor.snapshot, phase: monitor.observationPhase)
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider().opacity(0.48)

            VStack(spacing: 11) {
                participationCard
                keyMetrics

                ProtocolMilestoneMenuCard(
                    milestones: releaseChecker.protocolMilestones,
                    snapshot: monitor.snapshot
                )

                MenuBarResourceRow(
                    cpu: presentation.cpuText,
                    memory: presentation.memoryText
                )
                .padding(.horizontal, 2)
            }
            .padding(12)

            Divider().opacity(0.48)
            actions
        }
        .frame(width: 420)
        .background { ThemeCanvasBackground().ignoresSafeArea() }
        .redacted(reason: privacyMode.isEnabled ? .privacy : [])
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(spacing: 10) {
            ApplicationBrandMark(size: 34, theme: theme)
                .frame(width: 34, height: 34)
                .accessibilityLabel("QuilNode")

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text("QuilNode")
                        .font(.headline)
                    Text(presentation.versionText)
                        .font(.caption2.weight(.medium).monospacedDigit())
                        .foregroundStyle(theme.colors.secondaryText)
                }

                HStack(spacing: 5) {
                    Circle()
                        .fill(headerTint)
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)
                    Text(
                        presentation.hasLiveTelemetry
                            ? monitor.snapshot.health.label
                            : presentation.participationTitle)
                    Text("·")
                    TimelineView(.periodic(from: .now, by: 30)) { _ in
                        Text(presentation.hasLiveTelemetry ? monitor.snapshot.collectedAt : Date(), style: .relative)
                    }
                }
                .font(.caption)
                .foregroundStyle(theme.colors.secondaryText)
            }

            Spacer()

            if monitor.isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 28, height: 28)
                    .accessibilityLabel("Refreshing node status")
            } else {
                Text("LOCAL")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(theme.colors.success)
                    .padding(.horizontal, 8)
                    .frame(height: 24)
                    .background(theme.colors.success.opacity(0.10), in: Capsule())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var participationCard: some View {
        Button {
            openDashboard(.activity)
        } label: {
            MenuBarSectionSurface(tint: participationTint) {
                VStack(alignment: .leading, spacing: 11) {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: presentation.participationSystemImage)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(participationTint)
                            .frame(width: 34, height: 34)
                            .background(
                                participationTint.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 3) {
                            Text("PARTICIPATION")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .tracking(1.0)
                                .foregroundStyle(participationTint)
                            Text(presentation.participationTitle)
                                .font(.title3.weight(.bold))
                            Text(presentation.participationDetail)
                                .font(.caption)
                                .foregroundStyle(theme.colors.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.colors.secondaryText.opacity(0.7))
                            .padding(.top, 7)
                            .accessibilityHidden(true)
                    }

                    HStack(spacing: 7) {
                        if let count = presentation.participationCount {
                            MenuBarStatusChip(systemImage: "square.stack.3d.up.fill", tint: participationTint) {
                                PrivacyProtectedPhrase(
                                    value: String(count),
                                    suffix: presentation.participationCountSuffix,
                                    field: monitor.snapshot.activeShards > 0 ? .activeShardCount : .allocationCount
                                )
                            }
                        }

                        MenuBarStatusChip(
                            systemImage: monitor.snapshot.lastRewardCreditFrame == nil
                                ? "clock.badge" : "banknote.fill",
                            tint: rewardTint
                        ) {
                            Text(presentation.rewardTitle)
                        }
                        .help(presentation.rewardDetail)

                        Spacer(minLength: 0)
                    }

                    VStack(spacing: 5) {
                        HStack {
                            Text("Frame \(presentation.effectiveFrame.grouped)")
                                .font(.caption.weight(.semibold).monospacedDigit())
                            Spacer()
                            Text("Epoch \(presentation.epoch.grouped) · \(presentation.epochETA)")
                                .font(.caption2.weight(.medium).monospacedDigit())
                                .foregroundStyle(theme.colors.secondaryText)
                        }
                        ProgressView(value: presentation.epochProgress)
                            .progressViewStyle(.linear)
                            .tint(theme.colors.frame)
                            .accessibilityLabel("Epoch progress")
                            .accessibilityValue("\(Int(presentation.epochProgress * 100)) percent")
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel("Participation: \(presentation.participationTitle)")
        .accessibilityHint("Opens Activity in the dashboard")
    }

    private var keyMetrics: some View {
        MenuBarSectionSurface {
            VStack(spacing: 12) {
                Button {
                    openDashboard(.network)
                } label: {
                    HStack(spacing: 12) {
                        MenuBarValue(
                            title: "Peers",
                            value: presentation.hasLiveTelemetry ? String(monitor.snapshot.peers) : "—",
                            systemImage: "person.2.fill",
                            tint: theme.colors.info,
                            privacyField: .networkActivity
                        )
                        MenuBarValue(
                            title: "Reachability",
                            value: presentation.hasLiveTelemetry ? presentation.reachabilityTitle : "Checking…",
                            systemImage: monitor.snapshot.reachable == true
                                ? "arrow.down.left.circle.fill" : "arrow.up.right.circle",
                            tint: monitor.snapshot.reachable == true ? theme.colors.success : theme.colors.warning,
                            privacyField: .networkActivity
                        )
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(theme.colors.secondaryText.opacity(0.6))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens Network in the dashboard")

                Divider().opacity(0.42)

                Button {
                    openDashboard(.identity)
                } label: {
                    HStack(spacing: 12) {
                        MenuBarValue(
                            title: "Chain seniority",
                            value: !presentation.hasLiveTelemetry
                                ? "—"
                                : monitor.snapshot.seniority > 0
                                    ? monitor.snapshot.seniority.formatted(.number.grouping(.automatic))
                                    : "—",
                            systemImage: "clock.arrow.circlepath",
                            tint: theme.colors.accentSecondary,
                            privacyField: .seniority
                        )
                        MenuBarValue(
                            title: "QUIL balance",
                            value: presentation.hasLiveTelemetry ? presentation.quilBalanceText : "—",
                            systemImage: "wallet.bifold.fill",
                            tint: theme.colors.wallet,
                            privacyField: .quilBalance
                        )
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(theme.colors.secondaryText.opacity(0.6))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens Identity in the dashboard")
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 9) {
            Button {
                openDashboard(.overview)
            } label: {
                Label("Open Dashboard", systemImage: "rectangle.grid.2x2.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            HStack(spacing: 0) {
                MenuBarQuickAction(title: "Refresh", systemImage: "arrow.clockwise") {
                    Task { await monitor.refresh(forceNodeInfo: true) }
                }
                .disabled(monitor.isRefreshing)

                Divider().frame(height: 20)

                MenuBarQuickAction(
                    title: privacyMode.isEnabled ? "Privacy On" : "Privacy Off",
                    systemImage: privacyMode.isEnabled ? "eye.slash.fill" : "eye",
                    tint: privacyMode.isEnabled ? theme.colors.privacy : theme.colors.secondaryText
                ) {
                    privacyMode.toggle()
                }

                Divider().frame(height: 20)

                MenuBarQuickAction(title: "Settings…", systemImage: "gearshape.fill") {
                    dismiss()
                    DispatchQueue.main.async {
                        NSApp.activate(ignoringOtherApps: true)
                        openSettings()
                    }
                }

                Divider().frame(height: 20)

                MenuBarQuickAction(title: "Quit", systemImage: "power", tint: theme.colors.danger, role: .destructive) {
                    NSApp.terminate(nil)
                }
            }
        }
        .padding(12)
    }

    private var participationTint: Color {
        if monitor.observationPhase == .checkingProcess { return theme.colors.info }
        if monitor.observationPhase == .loadingTelemetry {
            return monitor.snapshot.isRunning ? theme.colors.success : theme.colors.danger
        }
        return monitor.snapshot.activeShards > 0
            ? theme.colors.success
            : (monitor.snapshot.isRunning ? theme.colors.warning : theme.colors.danger)
    }

    private var rewardTint: Color {
        monitor.snapshot.lastRewardCreditFrame == nil ? theme.colors.privacy : theme.colors.success
    }

    private var headerTint: Color {
        if monitor.observationPhase == .checkingProcess { return theme.colors.info }
        if monitor.observationPhase == .loadingTelemetry, monitor.snapshot.isRunning {
            return theme.colors.success
        }
        return theme.colors.health(monitor.snapshot.health)
    }

    private func openDashboard(_ destination: DashboardDestination) {
        dismiss()
        DispatchQueue.main.async {
            DashboardWindowPresenter.present(using: openWindow)
            commandCenter.send(.select(destination))
        }
    }
}
