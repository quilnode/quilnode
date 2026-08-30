import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

/// The glanceable operator surface shown from the macOS menu bar.
///
/// This view accepts immutable local evidence and actions rather than reaching
/// into app services. That separation prevents dashboard logic from leaking
/// into a compact surface and makes every state independently testable.
struct MenuBarContent: View {
    let snapshot: NodeSnapshot
    let phase: NodeObservationPhase
    let milestones: [ProtocolMilestone]
    let isRefreshing: Bool
    let privacyEnabled: Bool
    let onOpenDashboard: (DashboardDestination) -> Void
    let onRefresh: () -> Void
    let onTogglePrivacy: () -> Void
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    @Environment(\.quilTheme) private var theme

    private var presentation: MenuBarPresentation {
        MenuBarPresentation(snapshot: snapshot, phase: phase)
    }

    private var milestoneNotice: MenuBarMilestonePresentation? {
        MenuBarMilestonePresentation.resolve(milestones: milestones, snapshot: snapshot)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.42)

            VStack(alignment: .leading, spacing: 13) {
                participationHero

                if let milestoneNotice {
                    ProtocolMilestoneMenuCard(notice: milestoneNotice) {
                        onOpenDashboard(.activity)
                    }
                    .transition(.opacity)
                }

                evidenceSection
                resources
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)

            Divider().opacity(0.42)
            actions
        }
        .frame(width: 420)
        .background { ThemeCanvasBackground().ignoresSafeArea() }
        .redacted(reason: privacyEnabled ? .privacy : [])
        .accessibilityElement(children: .contain)
    }

    private var header: some View {
        HStack(spacing: 10) {
            ApplicationBrandMark(size: 36, theme: theme)
                .frame(width: 36, height: 36)
                .accessibilityLabel("QuilNode")

            VStack(alignment: .leading, spacing: 3) {
                Text("QuilNode")
                    .font(.headline.weight(.bold))

                HStack(spacing: 6) {
                    Circle()
                        .fill(headerTint)
                        .frame(width: 7, height: 7)
                        .accessibilityHidden(true)
                    Text(presentation.headerStatus)
                }
                .font(.caption)
                .foregroundStyle(snapshot.isRunning ? theme.colors.success : theme.colors.secondaryText)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text(presentation.versionText)
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(theme.colors.primaryText.opacity(0.82))
                    .padding(.horizontal, 8)
                    .frame(height: 22)
                    .background(theme.colors.surfaceElevated.opacity(0.86), in: Capsule())

                TimelineView(.periodic(from: .now, by: 5)) { context in
                    PrivacyProtectedText(
                        value: presentation.freshnessText(at: context.date),
                        field: .localTimestamp,
                        mask: .compact
                    )
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(theme.colors.secondaryText)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var participationHero: some View {
        Button {
            onOpenDashboard(.activity)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: presentation.participationSystemImage)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(participationTint)
                        .frame(width: 42, height: 42)
                        .background(
                            participationTint.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(presentation.participationTitle)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(participationTint)
                        Text(presentation.participationSummary)
                            .font(.subheadline)
                            .foregroundStyle(theme.colors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 7) {
                            if let count = presentation.participationCount {
                                MenuBarStatusPill(
                                    value: String(count),
                                    suffix: presentation.participationCountSuffix,
                                    systemImage: "square.stack.3d.up.fill",
                                    privacyField: snapshot.activeShards > 0 ? .activeShardCount : .allocationCount,
                                    tint: participationTint
                                )
                            }

                            Label(presentation.rewardTitle, systemImage: rewardSystemImage)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(rewardTint)
                        }
                        .padding(.top, 2)

                        Text(presentation.rewardDetail)
                            .font(.caption2)
                            .foregroundStyle(theme.colors.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                MenuBarEpochRunway(
                    frame: presentation.hasLiveTelemetry ? presentation.effectiveFrame : nil,
                    epoch: presentation.hasLiveTelemetry ? presentation.epoch : nil,
                    progress: presentation.hasLiveTelemetry && !privacyEnabled ? presentation.epochProgress : 0,
                    progressText: presentation.hasLiveTelemetry ? presentation.epochProgressText : "—",
                    eta: presentation.hasLiveTelemetry ? presentation.epochETA : "Reading"
                )
            }
            .padding(.horizontal, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(QuilPressFeedbackButtonStyle())
        .quilHoverSurface(tint: participationTint, cornerRadius: 13)
        .accessibilityLabel("Participation: \(presentation.participationTitle)")
        .accessibilityHint("Opens the local Activity flight recorder")
    }

    private var evidenceSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionLabel("EVIDENCE")

            MenuBarSectionSurface(contentPadding: 0) {
                VStack(spacing: 0) {
                    MenuBarEvidenceRow(
                        title: "Network",
                        systemImage: "network",
                        tint: theme.colors.info,
                        metrics: [
                            MenuBarEvidenceMetric(
                                label: "Peers",
                                value: presentation.hasLiveTelemetry ? String(snapshot.peers) : "—",
                                privacyField: .networkActivity,
                                tint: theme.colors.info
                            ),
                            MenuBarEvidenceMetric(
                                label: "Inbound",
                                value: presentation.hasLiveTelemetry ? presentation.reachabilityTitle : "Checking",
                                privacyField: .networkActivity,
                                tint: snapshot.reachable == true ? theme.colors.success : theme.colors.warning
                            ),
                        ]
                    ) {
                        onOpenDashboard(.network)
                    }

                    Divider().opacity(0.40).padding(.leading, 54)

                    MenuBarEvidenceRow(
                        title: "Identity",
                        systemImage: "person.text.rectangle.fill",
                        tint: theme.colors.accentSecondary,
                        metrics: [
                            MenuBarEvidenceMetric(
                                label: "Seniority",
                                value: presentation.seniorityText,
                                privacyField: .seniority,
                                tint: theme.colors.accentSecondary
                            ),
                            MenuBarEvidenceMetric(
                                label: "QUIL",
                                value: presentation.hasLiveTelemetry ? presentation.quilBalanceText : "—",
                                privacyField: .quilBalance,
                                tint: theme.colors.wallet
                            ),
                        ]
                    ) {
                        onOpenDashboard(.identity)
                    }
                }
            }
        }
    }

    private var resources: some View {
        VStack(alignment: .leading, spacing: 7) {
            sectionLabel("SYSTEM")

            MenuBarSectionSurface(contentPadding: 11) {
                HStack(spacing: 14) {
                    MenuBarResourceMeter(
                        title: "CPU",
                        value: presentation.hasLiveTelemetry ? presentation.cpuText : "—",
                        fraction: presentation.hasLiveTelemetry && !privacyEnabled ? presentation.cpuFraction : 0,
                        systemImage: "cpu",
                        tint: theme.colors.info
                    )

                    Divider().frame(height: 38)

                    MenuBarResourceMeter(
                        title: "Memory",
                        value: presentation.hasLiveTelemetry ? presentation.memoryText : "—",
                        fraction: presentation.hasLiveTelemetry && !privacyEnabled ? presentation.memoryFraction : 0,
                        systemImage: "memorychip",
                        tint: theme.colors.accentSecondary
                    )
                }
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 7) {
            Button {
                onOpenDashboard(.overview)
            } label: {
                Label("Open Dashboard", systemImage: "rectangle.grid.2x2.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(theme.colors.accent, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(QuilPressFeedbackButtonStyle(pressedOpacity: 0.9, pressedScale: 0.99))
            .quilHoverSurface(tint: theme.colors.accent, cornerRadius: 10)

            MenuBarActionTile(
                title: "Refresh",
                systemImage: "arrow.clockwise",
                isBusy: isRefreshing,
                isDisabled: isRefreshing,
                action: onRefresh
            )

            MenuBarActionTile(
                title: "Privacy",
                systemImage: privacyEnabled ? "eye.slash.fill" : "eye",
                tint: privacyEnabled ? theme.colors.privacy : theme.colors.secondaryText,
                action: onTogglePrivacy
            )

            MenuBarActionTile(title: "Settings", systemImage: "gearshape.fill", action: onOpenSettings)

            MenuBarActionTile(
                title: "Quit",
                systemImage: "power",
                tint: theme.colors.danger,
                role: .destructive,
                action: onQuit
            )
        }
        .padding(12)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .tracking(1.1)
            .foregroundStyle(theme.colors.secondaryText)
    }

    private var participationTint: Color {
        if phase == .checkingProcess { return theme.colors.info }
        if phase == .loadingTelemetry {
            return snapshot.isRunning ? theme.colors.success : theme.colors.danger
        }
        return snapshot.activeShards > 0
            ? theme.colors.success
            : (snapshot.isRunning ? theme.colors.warning : theme.colors.danger)
    }

    private var rewardTint: Color {
        snapshot.lastRewardCreditFrame == nil ? theme.colors.warning : theme.colors.success
    }

    private var rewardSystemImage: String {
        snapshot.lastRewardCreditFrame == nil ? "clock.badge" : "banknote.fill"
    }

    private var headerTint: Color {
        if phase == .checkingProcess { return theme.colors.info }
        if phase == .loadingTelemetry, snapshot.isRunning { return theme.colors.success }
        return theme.colors.health(snapshot.health)
    }
}
