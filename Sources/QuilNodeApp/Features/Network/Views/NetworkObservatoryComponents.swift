import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct NetworkObservatoryScopeGuide: View {
    @Environment(\.quilTheme) private var theme

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) { scopeCells }
            VStack(spacing: 0) { scopeCells }
        }
        .controlSurface()
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var scopeCells: some View {
        scopeCell(
            title: "Observed network",
            detail: "Shared shard table returned by this local qclient",
            systemImage: "point.3.connected.trianglepath.dotted",
            tint: theme.colors.accentSecondary
        )
        scopeCell(
            title: "My node",
            detail: "Local workers, allocations, runtime and reward evidence",
            systemImage: "desktopcomputer",
            tint: theme.colors.info
        )
    }

    private func scopeCell(
        title: String,
        detail: String,
        systemImage: String,
        tint: Color
    ) -> some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.colors.primaryText)
                Text(detail)
                    .font(.system(size: 9.2))
                    .foregroundStyle(theme.colors.secondaryText)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .overlay(alignment: .trailing) {
            Rectangle().fill(theme.colors.border.opacity(0.38)).frame(width: 0.5)
        }
    }
}

struct NetworkObservatoryMetricStrip: View {
    @Environment(\.quilTheme) private var theme

    let presentation: NetworkObservatoryPresentation

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) { metrics }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 138), spacing: 8)], spacing: 8) { metrics }
        }
        .controlSurface()
    }

    @ViewBuilder
    private var metrics: some View {
        metric(
            title: "Network shards", value: String(presentation.summary?.totalShards ?? presentation.shards.count),
            tint: theme.colors.accentSecondary)
        metric(
            title: "Prover memberships",
            value: String(presentation.proverMemberships),
            tint: theme.colors.info,
            help: "Sum of per-shard prover memberships in this observation; not a unique-prover count"
        )
        metric(title: "Healthy", value: String(presentation.summary?.healthyShards ?? 0), tint: theme.colors.success)
        metric(
            title: "Needs coverage",
            value: String((presentation.summary?.belowTargetShards ?? 0) + (presentation.summary?.atRiskShards ?? 0)),
            tint: theme.colors.warning)
        metric(
            title: "Unassigned", value: String(presentation.summary?.unassignedShards ?? 0), tint: theme.colors.muted)
        metric(
            title: "My allocations", value: String(presentation.localAllocationCount), tint: theme.colors.info,
            privacyField: .allocationCount)
    }

    private func metric(
        title: String,
        value: String,
        tint: Color,
        privacyField: PrivacyField? = nil,
        help: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(theme.colors.secondaryText)
            PrivacyProtectedText(value: value, field: privacyField)
                .font(.system(size: 19, weight: .semibold, design: theme.typography.dataDesign).monospacedDigit())
                .foregroundStyle(tint)
                .quilLiveValueTransition(value: value)
        }
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .overlay(alignment: .trailing) {
            Rectangle().fill(theme.colors.border.opacity(0.42)).frame(width: 0.5)
        }
        .help(help ?? title)
    }
}

struct NetworkObservatoryEvidenceRail: View {
    @Environment(\.quilTheme) private var theme

    let presentation: NetworkObservatoryPresentation

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 142), spacing: 0)], spacing: 0) {
            telemetryCells
        }
        .controlSurface()
    }

    @ViewBuilder
    private var telemetryCells: some View {
        telemetryCell(
            title: "Frame",
            value: presentation.frame.formatted(.number.grouping(.automatic)),
            detail: "Local chain head",
            tint: theme.colors.frame
        )
        epochCell
        telemetryCell(
            title: "Observed peers",
            value: String(presentation.peers),
            detail: "Known by this node",
            tint: theme.colors.info,
            privacyField: .networkActivity
        )
        telemetryCell(
            title: "Archive sources",
            value: presentation.archiveSources.map(String.init) ?? "—",
            detail: "Known by this node",
            tint: theme.colors.success,
            privacyField: .networkActivity
        )
        telemetryCell(
            title: "World state",
            value: presentation.summary?.worldState ?? "—",
            detail: "Reported by qclient",
            tint: theme.colors.wallet
        )
        telemetryCell(
            title: "Difficulty",
            value: presentation.summary?.difficulty?.formatted(.number.grouping(.automatic)) ?? "—",
            detail: "Shard table footer",
            tint: theme.colors.warning
        )
        telemetryCell(
            title: "Ring distribution",
            value:
                "\(presentation.ringDistribution.ring0)/\(presentation.ringDistribution.ring1)/\(presentation.ringDistribution.ring2)/\(presentation.ringDistribution.ring3Plus)",
            detail: "R0 / R1 / R2 / R3+",
            tint: theme.colors.accentSecondary
        )
        observationCell
    }

    private var epochCell: some View {
        VStack(alignment: .leading, spacing: 5) {
            telemetryTitle("Epoch progress")
            Text(presentation.epochProgress, format: .percent.precision(.fractionLength(1)))
                .font(.system(size: 17, weight: .semibold, design: .monospaced).monospacedDigit())
                .foregroundStyle(theme.colors.accentSecondary)
            ProgressView(value: presentation.epochProgress)
                .progressViewStyle(.linear)
                .tint(theme.colors.accentSecondary)
            Text(
                presentation.nextEpoch.map { "Epoch \(presentation.epoch) → \($0)" }
                    ?? "Epoch \(presentation.epoch)"
            )
            .font(.system(size: 8.5, design: .monospaced).monospacedDigit())
            .foregroundStyle(theme.colors.secondaryText)
        }
        .telemetryCell()
    }

    private var observationCell: some View {
        VStack(alignment: .leading, spacing: 5) {
            telemetryTitle("Observation")
            HStack(spacing: 6) {
                Circle().fill(evidenceTint).frame(width: 6, height: 6)
                PrivacyProtectedText(
                    value: presentation.observedAt?.formatted(date: .omitted, time: .shortened) ?? "—",
                    field: .localTimestamp
                )
                .font(.system(size: 17, weight: .semibold, design: .monospaced).monospacedDigit())
                .foregroundStyle(evidenceTint)
            }
            Text(presentation.evidenceLabel)
                .font(.system(size: 8.5, design: .monospaced))
                .foregroundStyle(theme.colors.secondaryText)
                .lineLimit(1)
        }
        .telemetryCell()
    }

    private func telemetryCell(
        title: String,
        value: String,
        detail: String,
        tint: Color,
        privacyField: PrivacyField? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            telemetryTitle(title)
            PrivacyProtectedText(value: value, field: privacyField)
                .font(.system(size: 17, weight: .semibold, design: .monospaced).monospacedDigit())
                .foregroundStyle(tint)
                .quilLiveValueTransition(value: value)
            Text(detail)
                .font(.system(size: 8.5, design: .monospaced))
                .foregroundStyle(theme.colors.secondaryText)
                .lineLimit(1)
        }
        .telemetryCell()
    }

    private func telemetryTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .tracking(0.7)
            .foregroundStyle(theme.colors.secondaryText)
    }

    private var evidenceTint: Color {
        switch presentation.evidenceState {
        case .current: theme.colors.success
        case .loading: theme.colors.info
        case .stale: theme.colors.warning
        case .unavailable: theme.colors.danger
        }
    }
}

struct NetworkShardGalaxyBadge: View {
    @Environment(\.quilTheme) private var theme

    let shard: NetworkShardPresentation
    let diameter: CGFloat

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) * 0.28
            context.fill(
                Path(
                    ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                ),
                with: .color(theme.colors.canvas.opacity(0.88))
            )
            context.stroke(
                Path(
                    ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                ),
                with: .color(tint.opacity(0.86)),
                lineWidth: 1.1
            )
            let samples =
                shard.observation.activeProvers > 0
                ? min(max(shard.observation.activeProvers * 3, 12), 28)
                : 0
            for index in 0..<samples {
                let angle = Double(index) * 2.399_963
                let orbit = radius * (1.22 + CGFloat((index * 31) % 100) / 220)
                let point = CGPoint(x: center.x + cos(angle) * orbit, y: center.y + sin(angle) * orbit)
                context.fill(
                    Path(ellipseIn: CGRect(x: point.x - 1.4, y: point.y - 1.4, width: 2.8, height: 2.8)),
                    with: .color(tint.opacity(0.86))
                )
            }
        }
        .frame(width: diameter, height: diameter)
        .background(tint.opacity(0.08), in: Circle())
        .overlay { Circle().strokeBorder(tint.opacity(0.26), lineWidth: 0.6) }
        .accessibilityHidden(true)
    }

    private var tint: Color {
        switch shard.coverage {
        case .healthy: theme.colors.success
        case .belowTarget: theme.colors.warning
        case .atRisk: theme.colors.danger
        case .unassigned: theme.colors.muted
        }
    }
}

private extension View {
    func telemetryCell() -> some View {
        self
            .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .overlay(alignment: .trailing) {
                Rectangle().fill(Color.primary.opacity(0.10)).frame(width: 0.5)
            }
    }
}
