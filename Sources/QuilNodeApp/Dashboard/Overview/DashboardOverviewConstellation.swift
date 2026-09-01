import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

/// A compact local-vantage summary for Overview. The complete topology,
/// filtering and per-shard inspection remain in Network Observatory.
struct DashboardOverviewConstellation: View {
    @Environment(\.quilTheme) private var theme
    @Environment(\.redactionReasons) private var redactionReasons

    let snapshot: NodeSnapshot
    let hasLiveTelemetry: Bool
    let onOpenNetwork: () -> Void

    private var presentation: NetworkObservatoryPresentation {
        .make(snapshot: snapshot)
    }

    private var displayedShards: [NetworkShardPresentation] {
        if redactionReasons.contains(.privacy) {
            // A local-only subset would reveal allocation cardinality even if
            // every label were masked. Keep a fixed public sample instead.
            return Array(presentation.shards.prefix(PrivacyLayoutPolicy.collectionPlaceholderCount))
        }

        let local = presentation.shards.filter(\.observation.isAllocated)
        if !local.isEmpty { return local }
        return Array(presentation.shards.prefix(5))
    }

    private var featuredShardIDs: Set<String> {
        Set(displayedShards.prefix(7).map(\.id))
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if hasLiveTelemetry, !presentation.shards.isEmpty {
                NetworkObservatoryCanvas(
                    shards: displayedShards,
                    featuredIDs: featuredShardIDs,
                    selectedID: nil,
                    isLocalNodeSelected: true,
                    onSelectShard: { _ in onOpenNetwork() },
                    onSelectLocalNode: onOpenNetwork,
                    zoom: 0.88,
                    archiveSources: presentation.archiveSources,
                    localAllocationCount: presentation.localAllocationCount
                )
            } else {
                LocalNetworkTopologyView(
                    snapshot: snapshot,
                    hasLiveTelemetry: hasLiveTelemetry
                )
            }

            Button(action: onOpenNetwork) {
                Label("Open Observatory", systemImage: "arrow.up.right")
                    .font(.system(size: 9.5, weight: .semibold))
                    .padding(.horizontal, 9)
                    .frame(minHeight: 27)
                    .background(theme.colors.canvas.opacity(0.90), in: Capsule())
                    .overlay {
                        Capsule().strokeBorder(
                            theme.colors.info.opacity(0.38),
                            lineWidth: max(theme.metrics.borderWidth, 0.5)
                        )
                    }
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.colors.info)
            .quilHoverSurface(tint: theme.colors.info, cornerRadius: 14)
            .padding(12)
            .accessibilityHint("Opens the full shard explorer")
        }
        .accessibilityElement(children: .contain)
    }
}
