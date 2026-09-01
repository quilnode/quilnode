import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct NetworkShardObservatoryInspector: View {
    @Environment(\.quilTheme) private var theme
    @Environment(\.redactionReasons) private var redactionReasons

    let shard: NetworkShardPresentation?
    let recentChange: NetworkShardChangeRecord?

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
                            field: hidesLocalAssociation
                                ? nil : (shard.observation.isAllocated ? .shardAllocation : nil)
                        )
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(theme.colors.secondaryText)
                    }
                    Spacer(minLength: 0)
                }

                statusBlock(shard)

                if let recentChange {
                    recentChangeBlock(recentChange)
                }

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

    private func recentChangeBlock(_ change: NetworkShardChangeRecord) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(theme.colors.accentSecondary)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(change.summary)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.colors.primaryText)
                HStack(spacing: 4) {
                    Text("Observed")
                    PrivacyProtectedText(
                        value: change.observedAt.formatted(date: .omitted, time: .shortened),
                        field: .localTimestamp
                    )
                }
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(theme.colors.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(9)
        .background(theme.colors.accentSecondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
        .help(change.fields.map(\.label).joined(separator: ", "))
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
