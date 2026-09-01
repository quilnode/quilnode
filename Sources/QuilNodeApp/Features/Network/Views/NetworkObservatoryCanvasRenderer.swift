import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct NetworkObservatoryCanvasRenderer {
    let theme: QuilTheme
    let shards: [NetworkShardPresentation]
    let selectedID: String?
    let zoom: CGFloat
    let archiveSources: Int?
    let localAllocationCount: Int
    let hidesLocalTopology: Bool

    func draw(
        in context: inout GraphicsContext,
        size: CGSize,
        layouts: [String: ShardConstellationNodeLayout]
    ) {
        drawField(in: &context, size: size)
        drawArchivePool(in: &context, size: size)
        drawAllocationLinks(in: &context, size: size, layouts: layouts)
        drawShards(in: &context, layouts: layouts)
        drawLocalNode(in: &context, size: size)
    }

    private func drawField(in context: inout GraphicsContext, size: CGSize) {
        let localNode = ShardConstellationLayout.localNodePoint(size: size)
        for radiusScale in [0.18, 0.31, 0.45] {
            let width = size.width * radiusScale * 2 * zoom
            let height = size.height * radiusScale * 1.28 * zoom
            let rect = CGRect(
                x: localNode.x - width / 2,
                y: localNode.y - height / 2,
                width: width,
                height: height
            )
            context.stroke(
                Path(ellipseIn: rect),
                with: .color(theme.colors.border.opacity(0.16)),
                style: StrokeStyle(lineWidth: 0.5, dash: [2.5, 7])
            )
        }

        for layer in 0...1 {
            let count = layer == 0 ? min(max(Int(size.width / 6), 90), 190) : 58
            for index in 0..<count {
                let point = ShardConstellationLayout.backgroundStarPoint(index: index, size: size, layer: layer)
                let prominent = (index + layer * 5).isMultiple(of: 13)
                let diameter: CGFloat = prominent ? (layer == 0 ? 1.8 : 1.3) : 0.7
                let opacity = prominent ? 0.29 : (layer == 0 ? 0.11 : 0.07)
                context.fill(
                    Path(ellipseIn: CGRect(x: point.x, y: point.y, width: diameter, height: diameter)),
                    with: .color((layer == 0 ? theme.colors.primaryText : theme.colors.info).opacity(opacity))
                )
            }
        }
    }

    private func drawAllocationLinks(
        in context: inout GraphicsContext,
        size: CGSize,
        layouts: [String: ShardConstellationNodeLayout]
    ) {
        guard !hidesLocalTopology else { return }
        let center = ShardConstellationLayout.localNodePoint(size: size)
        for shard in shards where shard.observation.isAllocated {
            guard let layout = layouts[shard.id] else { continue }
            var path = Path()
            path.move(to: center)
            let control = CGPoint(
                x: (center.x + layout.point.x) / 2,
                y: (center.y + layout.point.y) / 2 - min(22, abs(center.x - layout.point.x) * 0.08)
            )
            path.addQuadCurve(to: layout.point, control: control)
            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [theme.colors.accent.opacity(0.78), theme.colors.info.opacity(0.24)]),
                    startPoint: center,
                    endPoint: layout.point
                ),
                style: StrokeStyle(lineWidth: 1.05, lineCap: .round)
            )
        }
    }

    private func drawShards(
        in context: inout GraphicsContext,
        layouts: [String: ShardConstellationNodeLayout]
    ) {
        let ordered = shards.sorted {
            (layouts[$0.id]?.isFeatured == true ? 1 : 0) < (layouts[$1.id]?.isFeatured == true ? 1 : 0)
        }
        for (index, shard) in ordered.enumerated() {
            guard let layout = layouts[shard.id] else { continue }
            if layout.isFeatured {
                drawGalaxy(shard, index: index, layout: layout, in: &context)
            } else {
                drawBackgroundShard(shard, layout: layout, in: &context)
            }
        }
    }

    private func drawGalaxy(
        _ shard: NetworkShardPresentation,
        index: Int,
        layout: ShardConstellationNodeLayout,
        in context: inout GraphicsContext
    ) {
        let tint = coverageColor(shard.coverage)
        let radius = layout.radius
        let selected = selectedID == shard.id
        let selectionTint = selected ? theme.colors.accentSecondary : tint

        for multiplier in [2.0, 1.65, 1.34] {
            let haloRadius = radius * multiplier
            context.fill(
                Path(
                    ellipseIn: CGRect(
                        x: layout.point.x - haloRadius,
                        y: layout.point.y - haloRadius,
                        width: haloRadius * 2,
                        height: haloRadius * 2
                    )
                ),
                with: .color(selectionTint.opacity(multiplier == 2.0 ? 0.025 : 0.045))
            )
        }

        let samples =
            shard.observation.activeProvers > 0
            ? min(max(shard.observation.activeProvers * 3, 12), 48)
            : 0
        for sample in 0..<samples {
            let phase = Double(sample) * 2.399_963 + Double(index) * 0.61
            let spread = 1.03 + CGFloat((sample * 37 + index * 11) % 100) / 100 * 0.74
            let particleRadius = radius * spread
            let point = CGPoint(
                x: layout.point.x + cos(phase) * particleRadius,
                y: layout.point.y + sin(phase) * particleRadius
            )
            let diameter: CGFloat = sample.isMultiple(of: 7) ? 3.2 : 2.1
            context.fill(
                Path(
                    ellipseIn: CGRect(
                        x: point.x - diameter / 2,
                        y: point.y - diameter / 2,
                        width: diameter,
                        height: diameter
                    )
                ),
                with: .color(tint.opacity(sample.isMultiple(of: 7) ? 0.98 : 0.72))
            )
        }

        for multiplier in [1.0, 1.26, 1.52] {
            let ringRadius = radius * multiplier
            context.stroke(
                Path(
                    ellipseIn: CGRect(
                        x: layout.point.x - ringRadius,
                        y: layout.point.y - ringRadius,
                        width: ringRadius * 2,
                        height: ringRadius * 2
                    )
                ),
                with: .color(selectionTint.opacity(multiplier == 1.0 ? 0.76 : 0.20)),
                style: StrokeStyle(
                    lineWidth: selected && multiplier == 1.0 ? 1.45 : 0.65,
                    dash: multiplier == 1.0 ? [] : [2, 4]
                )
            )
        }
    }

    private func drawBackgroundShard(
        _ shard: NetworkShardPresentation,
        layout: ShardConstellationNodeLayout,
        in context: inout GraphicsContext
    ) {
        let tint = coverageColor(shard.coverage)
        let radius = layout.radius
        context.fill(
            Path(
                ellipseIn: CGRect(
                    x: layout.point.x - radius * 2.2,
                    y: layout.point.y - radius * 2.2,
                    width: radius * 4.4,
                    height: radius * 4.4
                )
            ),
            with: .color(tint.opacity(0.08))
        )
        context.fill(
            Path(
                ellipseIn: CGRect(
                    x: layout.point.x - radius,
                    y: layout.point.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
            ),
            with: .radialGradient(
                Gradient(colors: [tint.opacity(0.98), tint.opacity(0.48)]),
                center: layout.point,
                startRadius: 0,
                endRadius: radius
            )
        )
    }

    private func drawLocalNode(in context: inout GraphicsContext, size: CGSize) {
        let point = ShardConstellationLayout.localNodePoint(size: size)
        for radius: CGFloat in [36, 27, 18] {
            context.stroke(
                Path(
                    ellipseIn: CGRect(
                        x: point.x - radius,
                        y: point.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                ),
                with: .color(theme.colors.accent.opacity(radius == 18 ? 0.70 : 0.20)),
                style: StrokeStyle(lineWidth: radius == 18 ? 1.3 : 0.65, dash: radius == 18 ? [] : [2, 4])
            )
        }

        if !hidesLocalTopology {
            for index in 0..<min(localAllocationCount, 12) {
                let visibleCount = max(min(localAllocationCount, 12), 1)
                let angle = Double(index) / Double(visibleCount) * .pi * 2 - 0.45
                let satellite = CGPoint(x: point.x + cos(angle) * 27, y: point.y + sin(angle) * 27)
                context.fill(
                    Path(ellipseIn: CGRect(x: satellite.x - 2.8, y: satellite.y - 2.8, width: 5.6, height: 5.6)),
                    with: .color(theme.colors.info.opacity(0.95))
                )
            }
        }

        context.fill(
            Path(ellipseIn: CGRect(x: point.x - 9, y: point.y - 9, width: 18, height: 18)),
            with: .color(theme.colors.canvas)
        )
        context.stroke(
            Path(ellipseIn: CGRect(x: point.x - 9, y: point.y - 9, width: 18, height: 18)),
            with: .color(theme.colors.accent),
            lineWidth: 3
        )
    }

    private func drawArchivePool(in context: inout GraphicsContext, size: CGSize) {
        guard let archiveSources, archiveSources > 0 else { return }
        let anchor = ShardConstellationLayout.archiveAnchor(size: size)

        if !hidesLocalTopology {
            var path = Path()
            path.move(to: anchor)
            let local = ShardConstellationLayout.localNodePoint(size: size)
            path.addCurve(
                to: local,
                control1: CGPoint(x: anchor.x + 65, y: anchor.y - 8),
                control2: CGPoint(x: local.x - 90, y: local.y + 34)
            )
            context.stroke(
                path,
                with: .color(theme.colors.accentSecondary.opacity(0.38)),
                style: StrokeStyle(lineWidth: 0.85, dash: [3, 4])
            )
        }

        let sampleCount = hidesLocalTopology ? 1 : min(archiveSources, 7)
        for index in 0..<sampleCount {
            let angle = Double(index) / Double(max(sampleCount, 1)) * .pi * 2 + 0.4
            let orbit: CGFloat = sampleCount == 1 ? 0 : 22
            let point = CGPoint(x: anchor.x + cos(angle) * orbit, y: anchor.y + sin(angle) * orbit)
            let rect = CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10)
            context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(theme.colors.canvas))
            context.stroke(
                Path(roundedRect: rect, cornerRadius: 2),
                with: .color(theme.colors.accentSecondary.opacity(0.88)),
                lineWidth: 1.2
            )
        }
    }

    private func coverageColor(_ coverage: ShardCoverageState) -> Color {
        switch coverage {
        case .healthy: theme.colors.success
        case .belowTarget: theme.colors.warning
        case .atRisk: theme.colors.danger
        case .unassigned: theme.colors.muted
        }
    }
}
