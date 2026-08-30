import AppKit
import Charts
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

extension DashboardView {
    var overviewHero: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 7) {
                    Circle()
                        .fill(overviewTint)
                        .frame(width: 8, height: 8)
                    Text(overviewEyebrow)
                        .font(.caption2.weight(.bold))
                        .tracking(1.5)
                        .foregroundStyle(overviewTint)
                }
                provingPhaseTitleView
                    .font(
                        .system(
                            size: 36 * theme.typography.scale, weight: .bold, design: theme.typography.displayDesign))
                Text(provingPhaseDetail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 450, alignment: .leading)

                HStack(spacing: 8) {
                    ReadinessPill(
                        title: !nodeObservation.hasLiveTelemetry
                            ? "Reading enrollment"
                            : monitor.snapshot.seniority > 0
                                ? DashboardCopy.Overview.chainValueRead
                                : "Reading chain value",
                        systemImage: nodeObservation.hasLiveTelemetry && monitor.snapshot.seniority > 0
                            ? "link" : "clock",
                        tint: nodeObservation.hasLiveTelemetry && monitor.snapshot.seniority > 0
                            ? theme.colors.success : .secondary
                    )
                    ReadinessPill(
                        title: nodeObservation.hasLiveTelemetry && monitor.snapshot.peers > 0
                            ? "Mesh connected" : "Finding peers",
                        systemImage: "antenna.radiowaves.left.and.right",
                        tint: nodeObservation.hasLiveTelemetry && monitor.snapshot.peers > 0
                            ? theme.colors.info : .secondary
                    )
                    ReadinessPill(
                        title: nodeObservation.hasLiveTelemetry ? rewardStatusTitle : "Reading reward state",
                        systemImage: nodeObservation.hasLiveTelemetry ? rewardSystemImage : "clock",
                        tint: nodeObservation.hasLiveTelemetry ? rewardTint : .secondary
                    )
                }
            }

            Spacer(minLength: 10)

            if nodeObservation.hasLiveTelemetry {
                EpochProgressRing(
                    progress: epochProgress,
                    epoch: currentEpoch,
                    frame: effectiveFrame,
                    tint: theme.colors.frame,
                    etaLabel: epochCompactETA
                )
                .frame(width: 176, height: 176)
            } else {
                VStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.regular)
                        .tint(overviewTint)
                    Text(
                        monitor.observationPhase == .checkingProcess
                            ? "Reading service state"
                            : "Reading live telemetry"
                    )
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.colors.secondaryText)
                }
                .frame(width: 176, height: 176)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(nodeObservation.accessibilityStatus)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 21)
        .background { overviewHeroBackground }
        .overlay { overviewHeroBorder }
    }

    @ViewBuilder
    var overviewHeroBackground: some View {
        let shape = RoundedRectangle(cornerRadius: theme.metrics.heroCornerRadius, style: .continuous)
        switch theme.recipes.hero {
        case .card:
            shape.fill(
                LinearGradient(
                    colors: [overviewTint.opacity(0.13), theme.colors.accentSecondary.opacity(0.055), Color.clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        case .plate:
            shape.fill(theme.colors.surface.opacity(theme.components.surfaceOpacity))
        case .terminal:
            shape.fill(theme.colors.surface.opacity(0.58))
        }
    }

    @ViewBuilder
    var overviewHeroBorder: some View {
        let shape = RoundedRectangle(cornerRadius: theme.metrics.heroCornerRadius, style: .continuous)
        switch theme.recipes.hero {
        case .card:
            shape.strokeBorder(overviewTint.opacity(0.18), lineWidth: 0.8)
        case .plate:
            shape.strokeBorder(theme.colors.border.opacity(0.88), lineWidth: 1)
        case .terminal:
            shape.strokeBorder(
                theme.colors.accent.opacity(0.70),
                style: StrokeStyle(lineWidth: 1, dash: [7, 5])
            )
        }
    }

    var overviewMetricStrip: some View {
        HStack(spacing: 0) {
            OverviewStripMetric(
                title: DashboardCopy.Overview.frame, value: nodeObservation.value(effectiveFrame.grouped),
                detail: nodeObservation.detail(framePace), tint: theme.colors.frame, privacyField: nil)
            Divider().frame(height: 48)
            OverviewStripMetric(
                title: DashboardCopy.Overview.peers, value: nodeObservation.value("\(monitor.snapshot.peers)"),
                detail: nodeObservation.detail("\(monitor.snapshot.archivePeers) archive"), tint: theme.colors.info,
                privacyField: nil)
            Divider().frame(height: 48)
            OverviewStripMetric(
                title: DashboardCopy.Overview.seniority,
                value: nodeObservation.value(monitor.snapshot.seniority > 0 ? monitor.snapshot.seniority.grouped : "—"),
                detail: nodeObservation.detail(DashboardCopy.Overview.chainRegistry),
                tint: theme.colors.accentSecondary, privacyField: .seniority)
            Divider().frame(height: 48)
            OverviewStripMetric(
                title: DashboardCopy.Overview.quil,
                value: nodeObservation.value(monitor.snapshot.quilBalance?.compactDecimal ?? "—"),
                detail: nodeObservation.detail(balanceDetail), tint: theme.colors.wallet, privacyField: .quilBalance)
            Divider().frame(height: 48)
            OverviewStripMetric(
                title: DashboardCopy.Overview.uptime,
                value: nodeObservation.value(monitor.snapshot.processUptime ?? "—"),
                detail: nodeObservation.detail(DashboardCopy.Overview.nodeProcess), tint: theme.colors.success,
                privacyField: .nodeUptime)
        }
        .padding(.vertical, 13)
        .background { metricStripBackground }
        .overlay { metricStripBorder }
    }

    @ViewBuilder
    var metricStripBackground: some View {
        switch theme.recipes.metricStrip {
        case .band:
            RoundedRectangle(cornerRadius: theme.metrics.controlCornerRadius, style: .continuous)
                .fill(theme.colors.surface)
        case .ruled:
            Rectangle().fill(theme.colors.surface.opacity(0.42))
        case .cells:
            Rectangle().fill(theme.colors.surface.opacity(0.56))
        }
    }

    @ViewBuilder
    var metricStripBorder: some View {
        switch theme.recipes.metricStrip {
        case .band:
            EmptyView()
        case .ruled:
            VStack(spacing: 0) {
                Rectangle().fill(theme.colors.border.opacity(0.85)).frame(height: 1)
                Spacer(minLength: 0)
                Rectangle().fill(theme.colors.border.opacity(0.85)).frame(height: 1)
            }
        case .cells:
            Rectangle().strokeBorder(
                theme.colors.accent.opacity(0.62),
                style: StrokeStyle(lineWidth: 1, dash: [6, 4])
            )
        }
    }
}
