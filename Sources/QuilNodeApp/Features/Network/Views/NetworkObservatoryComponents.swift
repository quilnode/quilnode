import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

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

    private func metric(title: String, value: String, tint: Color, privacyField: PrivacyField? = nil) -> some View {
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
    }
}

struct NetworkObservatoryInspector: View {
    @Environment(\.quilTheme) private var theme
    @Environment(\.redactionReasons) private var redactionReasons

    let shard: NetworkShardPresentation?

    private var hidesLocalAssociation: Bool {
        redactionReasons.contains(.privacy) && shard?.observation.isAllocated == true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let shard {
                Text("SELECTED SHARD")
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(theme.colors.secondaryText)

                HStack(alignment: .center, spacing: 12) {
                    NetworkShardGalaxyBadge(shard: shard, diameter: 76)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(hidesLocalAssociation ? "Network shard" : shard.title)
                            .font(.headline)
                        PrivacyProtectedText(
                            value: shard.shortFilter,
                            field: shard.observation.isAllocated ? .shardAllocation : nil
                        )
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(theme.colors.secondaryText)
                    }
                    Spacer(minLength: 0)
                }

                statusBlock(shard)

                Divider().overlay(theme.colors.border.opacity(0.5))

                VStack(spacing: 10) {
                    datum("Active provers", String(shard.observation.activeProvers))
                    datum("Ring", String(shard.observation.ring))
                    datum("Data shards", String(shard.observation.dataShards))
                    datum("Shard size", shard.observation.shardSize)
                    datum("Estimated reward / frame", shard.observation.estimatedRewardPerFrame)
                    if shard.observation.isAllocated && !hidesLocalAssociation {
                        datum(
                            "Local worker",
                            shard.observation.worker ?? "Active",
                            privacyField: .hardwareProfile
                        )
                    }
                }

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield")
                    Text("Read from the local qclient")
                }
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(theme.colors.secondaryText)
            } else {
                VStack(alignment: .leading, spacing: 9) {
                    Image(systemName: "scope")
                        .font(.title2)
                        .foregroundStyle(theme.colors.info)
                    Text("Select a shard")
                        .font(.headline)
                    Text(
                        "Choose a point in the constellation to inspect its locally reported coverage, ring and reward estimate."
                    )
                    .font(.caption)
                    .foregroundStyle(theme.colors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .controlSurface(tint: shard.map { coverageTint($0.coverage) })
    }

    private func statusBlock(_ shard: NetworkShardPresentation) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Circle().fill(coverageTint(shard.coverage)).frame(width: 6, height: 6)
                Text(shard.coverage.label)
                    .font(.subheadline.weight(.semibold))
            }
            Text(shard.coverageDetail)
                .font(.caption)
                .foregroundStyle(theme.colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            if shard.observation.isAllocated && !hidesLocalAssociation {
                HStack(spacing: 5) {
                    Image(systemName: "location.fill")
                    Text("Allocated to this node")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.colors.info)
                .padding(.top, 2)
            }
        }
    }

    private func datum(_ label: String, _ value: String, privacyField: PrivacyField? = nil) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.caption)
                .foregroundStyle(theme.colors.secondaryText)
            Spacer(minLength: 4)
            PrivacyProtectedText(value: value, field: privacyField)
                .font(.system(size: 11, weight: .semibold, design: .monospaced).monospacedDigit())
                .foregroundStyle(theme.colors.primaryText)
                .lineLimit(1)
        }
    }

    private func coverageTint(_ state: ShardCoverageState) -> Color {
        switch state {
        case .healthy: theme.colors.success
        case .belowTarget: theme.colors.warning
        case .atRisk: theme.colors.danger
        case .unassigned: theme.colors.muted
        }
    }
}

struct NetworkObservatoryEvidenceRail: View {
    @Environment(\.quilTheme) private var theme

    let presentation: NetworkObservatoryPresentation

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) { telemetryCells }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 142), spacing: 0)], spacing: 0) {
                telemetryCells
            }
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
            detail: "Local peer table",
            tint: theme.colors.info,
            privacyField: .networkActivity
        )
        telemetryCell(
            title: "Archive sources",
            value: presentation.archiveSources.map(String.init) ?? "—",
            detail: "Known locally",
            tint: theme.colors.success,
            privacyField: .networkActivity
        )
        telemetryCell(
            title: "World state",
            value: presentation.summary?.worldState ?? "—",
            detail: "Reported by qclient",
            tint: theme.colors.wallet
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

private struct NetworkShardGalaxyBadge: View {
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
