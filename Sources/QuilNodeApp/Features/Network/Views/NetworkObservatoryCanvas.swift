import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct NetworkObservatoryCanvas: View {
    @Environment(\.quilTheme) private var theme
    @Environment(\.redactionReasons) private var redactionReasons

    let shards: [NetworkShardPresentation]
    let featuredIDs: Set<String>
    let selectedID: String?
    let isLocalNodeSelected: Bool
    let onSelectShard: (String) -> Void
    let onSelectLocalNode: () -> Void
    let zoom: CGFloat
    let archiveSources: Int?
    let localAllocationCount: Int

    private var hidesLocalTopology: Bool {
        redactionReasons.contains(.privacy)
    }

    var body: some View {
        GeometryReader { geometry in
            let layouts = ShardConstellationLayout.layouts(
                for: shards,
                featuredIDs: featuredIDs,
                selectedID: selectedID,
                size: geometry.size,
                zoom: zoom
            )
            let renderer = NetworkObservatoryCanvasRenderer(
                theme: theme,
                shards: shards,
                selectedID: selectedID,
                zoom: zoom,
                archiveSources: archiveSources,
                localAllocationCount: localAllocationCount,
                hidesLocalTopology: hidesLocalTopology
            )

            ZStack {
                Canvas(rendersAsynchronously: true) { context, size in
                    renderer.draw(in: &context, size: size, layouts: layouts)
                }
                .accessibilityHidden(true)

                ForEach(shards) { shard in
                    if let layout = layouts[shard.id] {
                        Button {
                            onSelectShard(shard.id)
                        } label: {
                            NetworkShardHitTarget(
                                shard: shard,
                                layout: layout,
                                isSelected: selectedID == shard.id
                            )
                        }
                        .buttonStyle(.plain)
                        .position(layout.point)
                        .accessibilityLabel(accessibilityLabel(for: shard))
                        .accessibilityAddTraits(selectedID == shard.id ? .isSelected : [])
                        .help("Inspect shard \(shard.shortFilter)")
                    }
                }

                localNodeControl(size: geometry.size)

                if (archiveSources ?? 0) > 0 {
                    archivePoolLabel(size: geometry.size)
                }

                if geometry.size.width >= 720 {
                    NetworkObservatoryLegend(hidesLocalTopology: hidesLocalTopology)
                        .fixedSize()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.leading, 15)
                        .padding(.top, 48)
                }
            }
            .clipped()
        }
        .background {
            RoundedRectangle(cornerRadius: theme.metrics.heroCornerRadius, style: .continuous)
                .fill(theme.colors.canvas.opacity(0.92))
                .overlay {
                    RadialGradient(
                        colors: [theme.colors.accent.opacity(0.15), .clear],
                        center: UnitPoint(x: 0.44, y: 0.54),
                        startRadius: 12,
                        endRadius: 520
                    )
                }
        }
        .overlay(alignment: .topLeading) {
            HStack(spacing: 6) {
                Circle().fill(theme.colors.success).frame(width: 6, height: 6)
                Text("LIVE LOCAL VANTAGE")
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .tracking(1.1)
            }
            .foregroundStyle(theme.colors.secondaryText)
            .padding(14)
        }
        .overlay {
            RoundedRectangle(cornerRadius: theme.metrics.heroCornerRadius, style: .continuous)
                .strokeBorder(
                    theme.colors.border.opacity(theme.components.borderOpacity),
                    lineWidth: max(theme.metrics.borderWidth, 0.5)
                )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Locally observed shard constellation")
        .accessibilityHint("Shard positions are a stable visual layout, not geographic locations")
    }

    private func localNodeControl(size: CGSize) -> some View {
        Button(action: onSelectLocalNode) {
            VStack(spacing: 2) {
                Spacer(minLength: 0)
                Text("My node")
                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.colors.primaryText)
                PrivacyProtectedText(value: "\(localAllocationCount) allocations", field: .allocationCount)
                    .font(.system(size: 8.5, design: .monospaced).monospacedDigit())
                    .foregroundStyle(theme.colors.secondaryText)
            }
            .padding(.bottom, 3)
            .frame(width: 112, height: 98)
            .contentShape(Rectangle())
            .background(
                isLocalNodeSelected ? theme.colors.accent.opacity(0.08) : .clear,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay {
                if isLocalNodeSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(theme.colors.accent.opacity(0.38), lineWidth: 0.7)
                }
            }
        }
        .buttonStyle(.plain)
        .position(
            x: ShardConstellationLayout.localNodePoint(size: size).x,
            y: ShardConstellationLayout.localNodePoint(size: size).y + 23
        )
        .accessibilityLabel("Inspect my local node")
        .accessibilityAddTraits(isLocalNodeSelected ? .isSelected : [])
        .help("Inspect local workers, allocations and reward evidence")
    }

    private func archivePoolLabel(size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Archive sources")
                .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
            PrivacyProtectedText(value: String(archiveSources ?? 0), field: .networkActivity)
                .font(.system(size: 9.5, weight: .bold, design: .monospaced).monospacedDigit())
        }
        .foregroundStyle(theme.colors.accentSecondary)
        .position(
            x: ShardConstellationLayout.archiveAnchor(size: size).x,
            y: ShardConstellationLayout.archiveAnchor(size: size).y - 42
        )
        .allowsHitTesting(false)
    }

    private func accessibilityLabel(for shard: NetworkShardPresentation) -> String {
        let local = shard.observation.isAllocated && !hidesLocalTopology ? ", allocated to this node" : ""
        return
            "Shard \(shard.shortFilter), \(shard.coverage.label), \(shard.observation.activeProvers) active provers, ring \(shard.observation.ring)\(local)"
    }
}
