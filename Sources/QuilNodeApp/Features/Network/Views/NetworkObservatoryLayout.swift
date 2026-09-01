import CoreGraphics

struct ShardConstellationNodeLayout: Equatable {
    let point: CGPoint
    let radius: CGFloat
    let isFeatured: Bool
}

/// A deterministic semantic layout: the local node and evidence-rich shards
/// receive room to breathe, while every other observed shard remains visible as
/// context. Positions are illustrative and intentionally never imply geography.
enum ShardConstellationLayout {
    private static let featuredCoordinates: [CGPoint] = [
        CGPoint(x: 0.31, y: 0.24),
        CGPoint(x: 0.49, y: 0.18),
        CGPoint(x: 0.68, y: 0.24),
        CGPoint(x: 0.79, y: 0.43),
        CGPoint(x: 0.78, y: 0.68),
        CGPoint(x: 0.63, y: 0.79),
        CGPoint(x: 0.45, y: 0.82),
        CGPoint(x: 0.27, y: 0.70),
        CGPoint(x: 0.61, y: 0.49),
        CGPoint(x: 0.86, y: 0.24),
    ]

    static func layouts(
        for shards: [NetworkShardPresentation],
        featuredIDs: Set<String>,
        selectedID: String?,
        size: CGSize,
        zoom: CGFloat
    ) -> [String: ShardConstellationNodeLayout] {
        let featured = shards.filter { featuredIDs.contains($0.id) }
        let selectedBackground = shards.first { $0.id == selectedID && !featuredIDs.contains($0.id) }
        let foreground = featured + (selectedBackground.map { [$0] } ?? [])
        let foregroundIDs = Set(foreground.map(\.id))
        let background = shards.filter { !foregroundIDs.contains($0.id) }

        var result: [String: ShardConstellationNodeLayout] = [:]
        for (index, shard) in foreground.enumerated() {
            let point = scaledPoint(
                base: featuredPoint(index: index, size: size),
                around: localNodePoint(size: size),
                zoom: zoom
            )
            let proverScale = min(CGFloat(max(shard.observation.activeProvers, 0)) * 0.65, 9)
            let selectedScale: CGFloat = shard.id == selectedID ? 4 : 0
            result[shard.id] = ShardConstellationNodeLayout(
                point: point,
                radius: (31 + proverScale + selectedScale) * sqrt(zoom),
                isFeatured: true
            )
        }

        for (index, shard) in background.enumerated() {
            let point = scaledPoint(
                base: backgroundPoint(index: index, count: background.count, size: size),
                around: localNodePoint(size: size),
                zoom: zoom
            )
            let radius = 4.8 + min(CGFloat(max(shard.observation.activeProvers, 0)), 10) * 0.22
            result[shard.id] = ShardConstellationNodeLayout(
                point: point,
                radius: radius * sqrt(zoom),
                isFeatured: false
            )
        }
        return result
    }

    static func localNodePoint(size: CGSize) -> CGPoint {
        if size.width < 720 {
            return CGPoint(x: size.width * 0.50, y: size.height * 0.56)
        }
        return CGPoint(x: size.width * 0.39, y: size.height * 0.59)
    }

    static func archiveAnchor(size: CGSize) -> CGPoint {
        if size.width < 720 {
            return CGPoint(x: size.width * 0.12, y: size.height * 0.84)
        }
        return CGPoint(x: size.width * 0.11, y: size.height * 0.79)
    }

    static func backgroundStarPoint(index: Int, size: CGSize, layer: Int = 0) -> CGPoint {
        let xSeed = (index * (layer == 0 ? 73 : 181) + 19 + layer * 31) % 997
        let ySeed = (index * (layer == 0 ? 151 : 97) + 47 + layer * 17) % 991
        return CGPoint(
            x: CGFloat(xSeed) / 997 * size.width,
            y: CGFloat(ySeed) / 991 * size.height
        )
    }

    private static func featuredPoint(index: Int, size: CGSize) -> CGPoint {
        let coordinate = featuredCoordinates[index % featuredCoordinates.count]
        let compactShift: CGFloat = size.width < 720 ? -0.01 : 0
        return CGPoint(
            x: size.width * (coordinate.x + compactShift),
            y: size.height * coordinate.y
        )
    }

    private static func backgroundPoint(index: Int, count: Int, size: CGSize) -> CGPoint {
        let center = CGPoint(x: size.width * 0.54, y: size.height * 0.50)
        let fraction = sqrt((CGFloat(index) + 0.62) / CGFloat(max(count, 1) + 1))
        let goldenAngle = Double.pi * (3 - sqrt(5.0))
        let angle = Double(index) * goldenAngle + 0.51
        return CGPoint(
            x: center.x + cos(angle) * size.width * 0.43 * fraction,
            y: center.y + sin(angle) * size.height * 0.43 * fraction
        )
    }

    private static func scaledPoint(base: CGPoint, around anchor: CGPoint, zoom: CGFloat) -> CGPoint {
        CGPoint(
            x: anchor.x + (base.x - anchor.x) * zoom,
            y: anchor.y + (base.y - anchor.y) * zoom
        )
    }
}
