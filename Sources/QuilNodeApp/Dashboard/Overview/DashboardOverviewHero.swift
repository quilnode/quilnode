import AppKit
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

extension DashboardView {
    var overviewHero: some View {
        GeometryReader { proxy in
            if proxy.size.width >= 880 {
                protocolHeroWide(width: proxy.size.width)
            } else {
                protocolHeroCompact(width: proxy.size.width)
            }
        }
        .frame(height: 326)
        .background(theme.colors.canvas.opacity(0.84))
        .overlay(alignment: .bottom) { protocolRule(opacity: 0.72) }
        .clipped()
    }

    private func protocolHeroWide(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            protocolHeroCopy
                .frame(width: width * 0.38, alignment: .leading)

            LocalNetworkTopologyView(
                snapshot: monitor.snapshot,
                hasLiveTelemetry: nodeObservation.hasLiveTelemetry
            )
            .frame(width: width * 0.42, height: 326)
            .clipped()

            protocolFramePanel
                .frame(width: width * 0.20, alignment: .leading)
        }
    }

    private func protocolHeroCompact(width: CGFloat) -> some View {
        ZStack {
            LocalNetworkTopologyView(
                snapshot: monitor.snapshot,
                hasLiveTelemetry: nodeObservation.hasLiveTelemetry
            )
            .frame(width: width * 0.64, height: 326)
            .offset(x: width * 0.08)
            .clipped()

            HStack(spacing: 0) {
                protocolHeroCopy
                    .frame(maxWidth: .infinity, alignment: .leading)
                protocolFramePanel
                    .frame(width: min(190, width * 0.28), alignment: .leading)
            }
        }
    }

    private var protocolHeroCopy: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                Circle()
                    .fill(protocolSignal)
                    .frame(width: 7, height: 7)
                    .shadow(color: protocolSignal.opacity(0.65), radius: 5)
                Text(overviewEyebrow)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(protocolSignal)
            }
            .padding(.bottom, 13)

            protocolStatusTitle
                .font(
                    .system(
                        size: 34 * theme.typography.scale,
                        weight: .bold,
                        design: .monospaced
                    )
                )
                .tracking(-1.4)
                .lineLimit(1)
                .minimumScaleFactor(0.68)

            Text(provingPhaseDetail)
                .font(.system(size: 12.5 * theme.typography.scale, design: theme.typography.displayDesign))
                .foregroundStyle(theme.colors.secondaryText)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 500, alignment: .leading)
                .padding(.top, 15)
                .padding(.bottom, 18)

            readinessBadges
        }
        .padding(.leading, 34)
        .padding(.trailing, 14)
        .frame(maxHeight: .infinity, alignment: .center)
    }

    @ViewBuilder
    private var protocolStatusTitle: some View {
        VStack(alignment: .leading, spacing: 2) {
            if !nodeObservation.hasLiveTelemetry {
                (Text("Reading ").foregroundStyle(theme.colors.primaryText)
                    + Text("local node.").foregroundStyle(protocolSignal))
                (Text("Telemetry ").foregroundStyle(theme.colors.primaryText)
                    + Text("loading.").foregroundStyle(protocolSignal))
            } else if !monitor.snapshot.isRunning {
                (Text("Node ").foregroundStyle(theme.colors.primaryText)
                    + Text("offline.").foregroundStyle(theme.colors.danger))
                (Text("Participation ").foregroundStyle(theme.colors.primaryText)
                    + Text("paused.").foregroundStyle(theme.colors.danger))
            } else if monitor.snapshot.activeShards > 0 {
                (Text("Allocations ").foregroundStyle(theme.colors.primaryText)
                    + Text("active.").foregroundStyle(protocolSignal))
                (Text(
                    monitor.snapshot.lastRewardCreditFrame == nil
                        ? "No reward credit " : "Reward credit "
                ).foregroundStyle(theme.colors.primaryText)
                    + Text("observed.").foregroundStyle(rewardTint))
            } else if monitor.snapshot.pendingJoins > 0 {
                (Text("Registered · ").foregroundStyle(theme.colors.primaryText)
                    + Text("joining.").foregroundStyle(protocolSignal))
                (Text("Activation ").foregroundStyle(theme.colors.primaryText)
                    + Text("in progress.").foregroundStyle(protocolSignal))
            } else {
                (Text("Online · ").foregroundStyle(theme.colors.primaryText)
                    + Text("awaiting allocation.").foregroundStyle(protocolSignal))
                (Text("Ready for ").foregroundStyle(theme.colors.primaryText)
                    + Text("shard work.").foregroundStyle(protocolSignal))
            }
        }
    }

    private var readinessBadges: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { readinessBadgeContent }
            VStack(alignment: .leading, spacing: 6) { readinessBadgeContent }
        }
    }

    @ViewBuilder
    private var readinessBadgeContent: some View {
        ProtocolStatusCheck(
            title: !nodeObservation.hasLiveTelemetry
                ? "Reading chain value"
                : monitor.snapshot.seniority > 0
                    ? DashboardCopy.Overview.chainValueRead : "Reading chain value",
            systemImage: monitor.snapshot.seniority > 0 ? "link" : "clock",
            tint: monitor.snapshot.seniority > 0 ? theme.colors.success : theme.colors.secondaryText
        )
        ProtocolStatusCheck(
            title: nodeObservation.hasLiveTelemetry && monitor.snapshot.peers > 0
                ? "Mesh connected" : "Finding peers",
            systemImage: "antenna.radiowaves.left.and.right",
            tint: nodeObservation.hasLiveTelemetry && monitor.snapshot.peers > 0
                ? protocolSignal : theme.colors.secondaryText
        )
        ProtocolStatusCheck(
            title: nodeObservation.hasLiveTelemetry ? rewardStatusTitle : "Reading reward state",
            systemImage: nodeObservation.hasLiveTelemetry ? rewardSystemImage : "clock",
            tint: nodeObservation.hasLiveTelemetry ? rewardTint : theme.colors.secondaryText
        )
    }

    private var protocolFramePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(nodeObservation.hasLiveTelemetry ? "EPOCH \(currentEpoch.grouped)" : "EPOCH")
                .protocolLabelStyle(color: protocolSignal)

            Text(nodeObservation.hasLiveTelemetry ? "→ \((currentEpoch + 1).grouped)" : "reading")
                .font(.system(size: 11, weight: .semibold, design: .monospaced).monospacedDigit())
                .foregroundStyle(theme.colors.secondaryText)
                .padding(.top, 5)

            Text("FRAME")
                .protocolLabelStyle(color: theme.colors.secondaryText)
                .padding(.top, 23)

            Text(nodeObservation.value(effectiveFrame.grouped))
                .font(
                    .system(
                        size: 34 * theme.typography.scale,
                        weight: .regular,
                        design: .monospaced
                    ).monospacedDigit()
                )
                .foregroundStyle(protocolSignal)
                .lineLimit(1)
                .minimumScaleFactor(0.64)
                .padding(.top, 7)
                .quilLiveValueTransition(value: effectiveFrame)

            Text(
                nodeObservation.hasLiveTelemetry
                    ? "of \((effectiveFrame + framesUntilEpoch).grouped)"
                    : "reading epoch boundary"
            )
            .font(.system(size: 11, design: .monospaced).monospacedDigit())
            .foregroundStyle(theme.colors.secondaryText)
            .lineLimit(1)
            .minimumScaleFactor(0.72)

            Text("EPOCH PROGRESS")
                .protocolLabelStyle(color: theme.colors.secondaryText)
                .padding(.top, 23)

            Text(
                nodeObservation.hasLiveTelemetry
                    ? epochProgress.formatted(.percent.precision(.fractionLength(1)))
                    : "—"
            )
            .font(
                .system(
                    size: 30 * theme.typography.scale,
                    weight: .regular,
                    design: .monospaced
                ).monospacedDigit()
            )
            .foregroundStyle(protocolSignal)
            .padding(.top, 6)

            ProgressView(value: nodeObservation.hasLiveTelemetry ? epochProgress : 0)
                .tint(protocolSignal)
                .padding(.top, 7)

            Text(
                nodeObservation.hasLiveTelemetry
                    ? "\(epochCompactETA) to Epoch \((currentEpoch + 1).grouped)"
                    : "Reading local pace"
            )
            .font(.system(size: 10.5, design: .monospaced).monospacedDigit())
            .foregroundStyle(theme.colors.secondaryText)
            .lineLimit(2)
            .padding(.top, 7)
        }
        .padding(.leading, 8)
        .padding(.trailing, 28)
        .frame(maxHeight: .infinity, alignment: .center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            nodeObservation.hasLiveTelemetry
                ? "Frame \(effectiveFrame), epoch \(currentEpoch), \(Int(epochProgress * 100)) percent complete, \(epochCompactETA)"
                : nodeObservation.accessibilityStatus
        )
    }

    var overviewMetricStrip: some View {
        HStack(spacing: 0) {
            ProtocolMetricCell(
                title: "Shards active",
                value: nodeObservation.value(String(monitor.snapshot.activeShards)),
                detail: nodeObservation.detail("Local registry"),
                tint: monitor.snapshot.activeShards > 0 ? theme.colors.success : protocolSignal,
                privacyField: .activeShardCount
            )
            protocolMetricDivider
            ProtocolMetricCell(
                title: "Archive sources",
                value: nodeObservation.value(monitor.snapshot.archiveSourceValue),
                detail: nodeObservation.detail(monitor.snapshot.archiveSourceDetail),
                tint: protocolSignal,
                privacyField: nil
            )
            protocolMetricDivider
            ProtocolMetricCell(
                title: "Network peers",
                value: nodeObservation.value(String(monitor.snapshot.peers)),
                detail: nodeObservation.detail(DashboardCopy.Activity.liveMesh),
                tint: protocolSignal,
                privacyField: nil
            )
            protocolMetricDivider
            ProtocolMetricCell(
                title: DashboardCopy.Overview.seniority,
                value: nodeObservation.value(
                    monitor.snapshot.seniority > 0 ? monitor.snapshot.seniority.grouped : "—"
                ),
                detail: nodeObservation.detail(DashboardCopy.Overview.chainRegistry),
                tint: theme.colors.accentSecondary,
                privacyField: .seniority
            )
            protocolMetricDivider
            ProtocolMetricCell(
                title: DashboardCopy.Overview.uptime,
                value: nodeObservation.value(monitor.snapshot.processUptime ?? "—"),
                detail: nodeObservation.detail(DashboardCopy.Overview.nodeProcess),
                tint: theme.colors.success,
                privacyField: .nodeUptime
            )
            protocolMetricDivider
            ProtocolMetricCell(
                title: "QUIL balance",
                value: nodeObservation.value(monitor.snapshot.quilBalance?.compactDecimal ?? "—"),
                detail: nodeObservation.detail(balanceDetail),
                tint: theme.colors.wallet,
                privacyField: .quilBalance
            )
        }
        .frame(minHeight: 112)
        .background(theme.colors.canvas.opacity(0.68))
        .overlay(alignment: .bottom) { protocolRule(opacity: 0.72) }
    }

    private var protocolMetricDivider: some View {
        Rectangle()
            .fill(theme.colors.border.opacity(0.56))
            .frame(width: max(theme.metrics.borderWidth, 0.5))
            .padding(.vertical, 18)
    }

    private var protocolSignal: Color {
        theme.colors.info
    }

    private func protocolRule(opacity: Double) -> some View {
        Rectangle()
            .fill(theme.colors.border.opacity(opacity))
            .frame(height: max(theme.metrics.borderWidth, 0.5))
            .allowsHitTesting(false)
    }
}

private struct ProtocolStatusCheck: View {
    @Environment(\.quilTheme) private var theme
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 9)
            .frame(minHeight: 32)
            .background(theme.colors.surface.opacity(0.74))
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(tint.opacity(0.36), lineWidth: max(theme.metrics.borderWidth, 0.5))
            }
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

private struct ProtocolMetricCell: View {
    @Environment(\.quilTheme) private var theme
    let title: String
    let value: String
    let detail: String
    let tint: Color
    let privacyField: PrivacyField?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .protocolLabelStyle(color: theme.colors.secondaryText)
            PrivacyProtectedText(value: value, field: privacyField)
                .font(
                    .system(
                        size: 20 * theme.typography.scale,
                        weight: .medium,
                        design: .monospaced
                    ).monospacedDigit()
                )
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .quilLiveValueTransition(value: value)
            Text(detail)
                .font(.system(size: 10.5))
                .foregroundStyle(theme.colors.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private extension View {
    func protocolLabelStyle(color: Color) -> some View {
        font(.system(size: 9, weight: .bold, design: .monospaced))
            .tracking(1.25)
            .foregroundStyle(color)
    }
}
