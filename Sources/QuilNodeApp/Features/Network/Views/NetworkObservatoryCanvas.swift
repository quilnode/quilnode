import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

struct NetworkObservatoryCanvas: View {
    @Environment(\.quilTheme) private var theme
    @Environment(\.redactionReasons) private var redactionReasons

    let shards: [NetworkShardPresentation]
    @Binding var selectedID: String?
    let zoom: CGFloat

    private var hidesLocalTopology: Bool {
        redactionReasons.contains(.privacy)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Canvas(rendersAsynchronously: true) { context, size in
                    drawField(in: &context, size: size)
                    drawAllocationLinks(in: &context, size: size)
                    drawShards(in: &context, size: size)
                    drawLocalNode(in: &context, size: size)
                }
                .accessibilityHidden(true)

                ForEach(Array(shards.enumerated()), id: \.element.id) { index, shard in
                    Button {
                        selectedID = shard.id
                    } label: {
                        Circle()
                            .fill(.clear)
                            .contentShape(Circle())
                            .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.plain)
                    .position(
                        ShardConstellationLayout.point(
                            index: index,
                            count: shards.count,
                            size: geometry.size,
                            zoom: zoom
                        )
                    )
                    .accessibilityLabel(accessibilityLabel(for: shard))
                    .accessibilityAddTraits(selectedID == shard.id ? .isSelected : [])
                    .help("Inspect shard \(shard.shortFilter)")
                }
            }
            .clipped()
        }
        .background {
            RoundedRectangle(cornerRadius: theme.metrics.heroCornerRadius, style: .continuous)
                .fill(theme.colors.canvas.opacity(0.86))
                .overlay {
                    RadialGradient(
                        colors: [theme.colors.accent.opacity(0.12), .clear],
                        center: .center,
                        startRadius: 8,
                        endRadius: 430
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

    private func drawField(in context: inout GraphicsContext, size: CGSize) {
        let center = ShardConstellationLayout.localNodePoint(size: size)
        for radiusScale in [0.21, 0.36, 0.49] {
            let width = size.width * radiusScale * 2 * zoom
            let height = size.height * radiusScale * 1.36 * zoom
            let rect = CGRect(
                x: center.x - width / 2,
                y: center.y - height / 2,
                width: width,
                height: height
            )
            context.stroke(
                Path(ellipseIn: rect),
                with: .color(theme.colors.border.opacity(0.22)),
                style: StrokeStyle(lineWidth: 0.55, dash: [2.5, 6])
            )
        }

        let starCount = min(max(Int(size.width / 14), 44), 92)
        for index in 0..<starCount {
            let point = ShardConstellationLayout.backgroundPoint(index: index, size: size)
            let diameter: CGFloat = index.isMultiple(of: 11) ? 1.8 : 0.9
            context.fill(
                Path(ellipseIn: CGRect(x: point.x, y: point.y, width: diameter, height: diameter)),
                with: .color(theme.colors.primaryText.opacity(index.isMultiple(of: 11) ? 0.28 : 0.12))
            )
        }
    }

    private func drawAllocationLinks(in context: inout GraphicsContext, size: CGSize) {
        guard !hidesLocalTopology else { return }
        let center = ShardConstellationLayout.localNodePoint(size: size)
        for (index, shard) in shards.enumerated() where shard.observation.isAllocated {
            let point = ShardConstellationLayout.point(index: index, count: shards.count, size: size, zoom: zoom)
            var path = Path()
            path.move(to: center)
            let control = CGPoint(x: (center.x + point.x) / 2, y: min(center.y, point.y) - 18)
            path.addQuadCurve(to: point, control: control)
            context.stroke(
                path,
                with: .linearGradient(
                    Gradient(colors: [theme.colors.accent.opacity(0.65), theme.colors.accentSecondary.opacity(0.28)]),
                    startPoint: center,
                    endPoint: point
                ),
                style: StrokeStyle(lineWidth: 1.15, lineCap: .round, dash: [3, 3])
            )
        }
    }

    private func drawShards(in context: inout GraphicsContext, size: CGSize) {
        for (index, shard) in shards.enumerated() {
            let point = ShardConstellationLayout.point(index: index, count: shards.count, size: size, zoom: zoom)
            let color = coverageColor(shard.coverage)
            let isSelected = selectedID == shard.id
            let showsLocalMarker = shard.observation.isAllocated && !hidesLocalTopology
            let radius: CGFloat = showsLocalMarker ? 8.5 : 6.5

            context.fill(
                Path(
                    ellipseIn: CGRect(
                        x: point.x - radius * 2.2, y: point.y - radius * 2.2, width: radius * 4.4, height: radius * 4.4)
                ),
                with: .color(color.opacity(isSelected ? 0.22 : 0.09))
            )
            if isSelected {
                context.stroke(
                    Path(
                        ellipseIn: CGRect(
                            x: point.x - radius * 1.7, y: point.y - radius * 1.7, width: radius * 3.4,
                            height: radius * 3.4)),
                    with: .color(color.opacity(0.82)),
                    style: StrokeStyle(lineWidth: 1, dash: [2, 3])
                )
            }
            context.fill(
                Path(
                    ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                with: .radialGradient(
                    Gradient(colors: [color.opacity(0.98), color.opacity(0.56)]),
                    center: point,
                    startRadius: 0,
                    endRadius: radius
                )
            )
            context.stroke(
                Path(
                    ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)),
                with: .color(theme.colors.primaryText.opacity(showsLocalMarker ? 0.74 : 0.28)),
                lineWidth: showsLocalMarker ? 1.1 : 0.55
            )

            let proverSamples = min(shard.observation.activeProvers, 10)
            guard proverSamples > 0 else { continue }
            for prover in 0..<proverSamples {
                let angle = Double(prover) / Double(proverSamples) * .pi * 2 + Double(index) * 0.37
                let orbit = radius + 6.5
                let dot = CGPoint(x: point.x + cos(angle) * orbit, y: point.y + sin(angle) * orbit)
                context.fill(
                    Path(ellipseIn: CGRect(x: dot.x - 1.25, y: dot.y - 1.25, width: 2.5, height: 2.5)),
                    with: .color(color.opacity(0.82))
                )
            }
        }
    }

    private func drawLocalNode(in context: inout GraphicsContext, size: CGSize) {
        let point = ShardConstellationLayout.localNodePoint(size: size)
        context.fill(
            Path(ellipseIn: CGRect(x: point.x - 25, y: point.y - 25, width: 50, height: 50)),
            with: .color(theme.colors.accent.opacity(0.10))
        )
        context.stroke(
            Path(ellipseIn: CGRect(x: point.x - 18, y: point.y - 18, width: 36, height: 36)),
            with: .color(theme.colors.accent.opacity(0.56)),
            style: StrokeStyle(lineWidth: 0.9, dash: [3, 3])
        )
        context.fill(
            Path(ellipseIn: CGRect(x: point.x - 5.5, y: point.y - 5.5, width: 11, height: 11)),
            with: .color(theme.colors.accent)
        )
    }

    private func coverageColor(_ coverage: ShardCoverageState) -> Color {
        switch coverage {
        case .healthy: theme.colors.success
        case .belowTarget: theme.colors.warning
        case .atRisk: theme.colors.danger
        case .unassigned: theme.colors.muted
        }
    }

    private func accessibilityLabel(for shard: NetworkShardPresentation) -> String {
        let local = shard.observation.isAllocated && !hidesLocalTopology ? ", allocated to this node" : ""
        return
            "Shard \(shard.shortFilter), \(shard.coverage.label), \(shard.observation.activeProvers) active provers, ring \(shard.observation.ring)\(local)"
    }
}

enum ShardConstellationLayout {
    static func localNodePoint(size: CGSize) -> CGPoint {
        CGPoint(x: size.width * 0.5, y: size.height * 0.51)
    }

    static func point(index: Int, count: Int, size: CGSize, zoom: CGFloat) -> CGPoint {
        guard count > 0 else { return localNodePoint(size: size) }
        let center = localNodePoint(size: size)
        let fraction = sqrt((CGFloat(index) + 0.82) / CGFloat(count + 1))
        let goldenAngle = Double.pi * (3 - sqrt(5.0))
        let angle = Double(index) * goldenAngle - 0.72
        let maximumX = size.width * 0.42 * zoom
        let maximumY = size.height * 0.36 * zoom
        return CGPoint(
            x: center.x + cos(angle) * maximumX * fraction,
            y: center.y + sin(angle) * maximumY * fraction
        )
    }

    static func backgroundPoint(index: Int, size: CGSize) -> CGPoint {
        let xSeed = (index * 73 + 19) % 997
        let ySeed = (index * 151 + 47) % 991
        return CGPoint(
            x: CGFloat(xSeed) / 997 * size.width,
            y: CGFloat(ySeed) / 991 * size.height
        )
    }
}
