import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

/// A bounded, deterministic view of the relationships the local node can
/// actually observe. This is intentionally not a global network map: peer and
/// archive counts are sampled into a stable visual density, while shard paths
/// are drawn only from concrete local allocation records.
struct LocalNetworkTopologyView: View {
    @Environment(\.quilTheme) private var theme
    @Environment(\.redactionReasons) private var redactionReasons

    let snapshot: NodeSnapshot
    let hasLiveTelemetry: Bool

    private var hidesSensitiveValues: Bool {
        redactionReasons.contains(.privacy)
    }

    private var visualAllocationCount: Int {
        hidesSensitiveValues ? 0 : min(snapshot.shardAllocations.count, 12)
    }

    var body: some View {
        ZStack {
            topologyCanvas

            VStack(spacing: 4) {
                ApplicationBrandMark(size: 50, theme: theme)
                Text(hasLiveTelemetry && snapshot.isRunning ? "LOCAL NODE" : "READING NODE")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(theme.colors.primaryText)
            }
            .padding(10)
            .background(theme.colors.canvas.opacity(0.88), in: Circle())
            .overlay {
                Circle()
                    .strokeBorder(theme.colors.info.opacity(0.72), lineWidth: 1)
            }
            .shadow(color: theme.colors.info.opacity(0.22), radius: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text("LOCAL TOPOLOGY")
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .tracking(1.35)
                    .foregroundStyle(theme.colors.info)
                Text("Observed relationships · not a global map")
                    .font(.system(size: 9.5))
                    .foregroundStyle(theme.colors.secondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.top, 18)
            .padding(.leading, 16)

            topologyLegend
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.horizontal, 12)
                .padding(.bottom, 15)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var topologyCanvas: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            let center = CGPoint(x: size.width * 0.51, y: size.height * 0.49)
            let peerRect = topologyRect(center: center, width: size.width * 0.78, height: size.height * 0.52)
            let archiveRect = topologyRect(center: center, width: size.width * 0.56, height: size.height * 0.36)
            let shardRect = topologyRect(center: center, width: size.width * 0.32, height: size.height * 0.22)

            drawOrbit(peerRect, in: &context, color: theme.colors.border.opacity(0.62), dash: [4, 6])
            drawOrbit(archiveRect, in: &context, color: theme.colors.info.opacity(0.32), dash: [])
            drawOrbit(shardRect, in: &context, color: theme.colors.accentSecondary.opacity(0.30), dash: [2, 5])

            let peerSamples = hasLiveTelemetry ? min(max(snapshot.peers / 5, 10), 58) : 14
            for index in 0..<peerSamples {
                let point = point(on: peerRect, index: index, count: peerSamples, offset: 0.17)
                let emphasized = index % 9 == 0
                let diameter: CGFloat = emphasized ? 4.2 : 2.2
                context.fill(
                    Path(
                        ellipseIn: CGRect(
                            x: point.x - diameter / 2, y: point.y - diameter / 2,
                            width: diameter, height: diameter)),
                    with: .color(theme.colors.info.opacity(emphasized ? 0.92 : 0.46))
                )
            }

            let archiveSamples = hasLiveTelemetry ? min(snapshot.archivePeers, 10) : 0
            for index in 0..<archiveSamples {
                let point = point(on: archiveRect, index: index, count: max(archiveSamples, 1), offset: 0.39)
                var link = Path()
                link.move(to: center)
                link.addLine(to: point)
                context.stroke(link, with: .color(theme.colors.info.opacity(0.13)), lineWidth: 0.6)
                context.fill(
                    Path(
                        roundedRect: CGRect(x: point.x - 3.5, y: point.y - 3.5, width: 7, height: 7), cornerRadius: 1.5),
                    with: .color(theme.colors.success.opacity(0.92))
                )
            }

            for index in 0..<visualAllocationCount {
                let point = point(on: shardRect, index: index, count: max(visualAllocationCount, 1), offset: 0.08)
                var path = Path()
                path.move(to: center)
                path.addLine(to: point)
                context.stroke(path, with: .color(theme.colors.accentSecondary.opacity(0.52)), lineWidth: 1.1)
                context.fill(
                    Path(ellipseIn: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)),
                    with: .color(theme.colors.accentSecondary)
                )
            }
        }
        .accessibilityHidden(true)
    }

    private var topologyLegend: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) { legendContent }
            VStack(alignment: .leading, spacing: 5) { legendContent }
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 30)
        .background(theme.colors.canvas.opacity(0.82), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(theme.colors.border.opacity(0.52), lineWidth: 0.5)
        }
    }

    @ViewBuilder
    private var legendContent: some View {
        TopologyLegendItem(
            color: theme.colors.info,
            value: hasLiveTelemetry ? String(snapshot.peers) : "—",
            label: "peers"
        )
        TopologyLegendItem(
            color: theme.colors.success,
            value: hasLiveTelemetry ? String(snapshot.archivePeers) : "—",
            label: "archives",
            shape: .square
        )
        HStack(spacing: 5) {
            Circle()
                .fill(theme.colors.accentSecondary)
                .frame(width: 6, height: 6)
            PrivacyProtectedText(
                value: hasLiveTelemetry ? String(snapshot.totalAllocations) : "—",
                field: .allocationCount
            )
            .font(.system(size: 9.5, weight: .semibold, design: .monospaced).monospacedDigit())
            Text(hidesSensitiveValues ? "allocations hidden" : "allocations")
                .font(.system(size: 9.5))
                .foregroundStyle(theme.colors.secondaryText)
        }
    }

    private var accessibilitySummary: String {
        guard hasLiveTelemetry else { return "Reading local network topology" }
        let allocationSummary = hidesSensitiveValues ? "Allocation state hidden." : "Local allocation state shown."
        return
            "Local topology: \(snapshot.peers) peers and \(snapshot.archivePeers) archives. \(allocationSummary) This is not a global network map."
    }

    private func topologyRect(center: CGPoint, width: CGFloat, height: CGFloat) -> CGRect {
        CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height)
    }

    private func point(on rect: CGRect, index: Int, count: Int, offset: Double) -> CGPoint {
        let angle = ((Double(index) / Double(max(count, 1))) + offset) * .pi * 2
        return CGPoint(
            x: rect.midX + cos(angle) * rect.width / 2,
            y: rect.midY + sin(angle) * rect.height / 2
        )
    }

    private func drawOrbit(
        _ rect: CGRect,
        in context: inout GraphicsContext,
        color: Color,
        dash: [CGFloat]
    ) {
        context.stroke(
            Path(ellipseIn: rect),
            with: .color(color),
            style: StrokeStyle(lineWidth: 0.7, dash: dash)
        )
    }
}

private struct TopologyLegendItem: View {
    enum Shape { case circle, square }

    @Environment(\.quilTheme) private var theme
    let color: Color
    let value: String
    let label: String
    var shape: Shape = .circle

    var body: some View {
        HStack(spacing: 5) {
            Group {
                switch shape {
                case .circle: Circle().fill(color)
                case .square: RoundedRectangle(cornerRadius: 1.5).fill(color)
                }
            }
            .frame(width: 6, height: 6)
            Text(value)
                .font(.system(size: 9.5, weight: .semibold, design: .monospaced).monospacedDigit())
                .foregroundStyle(theme.colors.primaryText)
            Text(label)
                .font(.system(size: 9.5))
                .foregroundStyle(theme.colors.secondaryText)
        }
    }
}
