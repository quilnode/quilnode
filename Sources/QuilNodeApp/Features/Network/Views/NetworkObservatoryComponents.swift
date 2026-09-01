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
                HStack(alignment: .top, spacing: 10) {
                    ZStack {
                        Circle().fill(coverageTint(shard.coverage).opacity(0.14))
                        Circle().fill(coverageTint(shard.coverage)).frame(width: 8, height: 8)
                    }
                    .frame(width: 30, height: 30)

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
            HStack(spacing: 14) { content }
            VStack(alignment: .leading, spacing: 7) { content }
        }
        .font(.system(size: 9.5, design: .monospaced).monospacedDigit())
        .foregroundStyle(theme.colors.secondaryText)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .controlSurface()
    }

    @ViewBuilder
    private var content: some View {
        evidenceItem("Frame", String(presentation.frame), tint: theme.colors.frame)
        evidenceItem("Epoch", String(presentation.epoch), tint: theme.colors.accentSecondary)
        evidenceItem("Peers", String(presentation.peers), tint: theme.colors.info, privacyField: .networkActivity)
        evidenceItem("Archives", presentation.archiveSources.map(String.init) ?? "—", tint: theme.colors.success)
        if let world = presentation.summary?.worldState {
            evidenceItem("World", world, tint: theme.colors.wallet)
        }
        Spacer(minLength: 6)
        HStack(spacing: 5) {
            Circle().fill(evidenceTint).frame(width: 5, height: 5)
            Text(presentation.evidenceLabel)
            if let date = presentation.observedAt {
                PrivacyProtectedText(value: date.formatted(date: .omitted, time: .shortened), field: .localTimestamp)
            }
        }
    }

    private func evidenceItem(_ label: String, _ value: String, tint: Color, privacyField: PrivacyField? = nil)
        -> some View
    {
        HStack(spacing: 4) {
            Text(label).foregroundStyle(theme.colors.secondaryText)
            PrivacyProtectedText(value: value, field: privacyField)
                .fontWeight(.semibold)
                .foregroundStyle(tint)
        }
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
