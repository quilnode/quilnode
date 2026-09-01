import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct NetworkShardHitTarget: View {
    @Environment(\.quilTheme) private var theme

    let shard: NetworkShardPresentation
    let layout: ShardConstellationNodeLayout
    let isSelected: Bool

    var body: some View {
        if layout.isFeatured {
            ZStack {
                Circle()
                    .fill(theme.colors.canvas.opacity(0.78))
                    .frame(width: layout.radius * 1.65, height: layout.radius * 1.65)
                VStack(spacing: 1) {
                    PrivacyProtectedText(
                        value: shard.shortFilter,
                        field: shard.observation.isAllocated ? .shardAllocation : nil
                    )
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundStyle(theme.colors.primaryText)
                    Text("Ring \(shard.observation.ring)")
                        .font(.system(size: 8.5, design: .monospaced).monospacedDigit())
                        .foregroundStyle(theme.colors.secondaryText)
                    Text("\(shard.observation.activeProvers) provers")
                        .font(.system(size: 8.5, weight: .semibold, design: .monospaced).monospacedDigit())
                        .foregroundStyle(coverageTint)
                }
            }
            .frame(width: layout.radius * 2.6, height: layout.radius * 2.6)
            .contentShape(Circle())
            .scaleEffect(isSelected ? 1.035 : 1)
        } else {
            Circle()
                .fill(.clear)
                .contentShape(Circle())
                .frame(width: max(layout.radius * 4.4, 30), height: max(layout.radius * 4.4, 30))
        }
    }

    private var coverageTint: Color {
        switch shard.coverage {
        case .healthy: theme.colors.success
        case .belowTarget: theme.colors.warning
        case .atRisk: theme.colors.danger
        case .unassigned: theme.colors.muted
        }
    }
}

struct NetworkObservatoryLegend: View {
    @Environment(\.quilTheme) private var theme

    let hidesLocalTopology: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            legendItem("Healthy", color: theme.colors.success)
            legendItem("Below target", color: theme.colors.warning)
            legendItem("At risk", color: theme.colors.danger)
            legendItem("Unassigned", color: theme.colors.muted)
            Divider().overlay(theme.colors.border.opacity(0.44))
            HStack(spacing: 6) {
                Image(systemName: "circle.grid.3x3.fill")
                    .foregroundStyle(theme.colors.info)
                Text("Dots · prover sample")
            }
            if !hidesLocalTopology {
                HStack(spacing: 6) {
                    Image(systemName: "line.diagonal")
                        .foregroundStyle(theme.colors.accent)
                    Text("Line · local allocation")
                }
            }
            Text("Layout is illustrative")
                .foregroundStyle(theme.colors.secondaryText.opacity(0.72))
        }
        .font(.system(size: 8.5, design: .monospaced))
        .foregroundStyle(theme.colors.secondaryText)
        .padding(10)
        .background(theme.colors.canvas.opacity(0.72), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(theme.colors.border.opacity(0.28), lineWidth: 0.5)
        }
        .allowsHitTesting(false)
    }

    private func legendItem(_ title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(title)
        }
    }
}
