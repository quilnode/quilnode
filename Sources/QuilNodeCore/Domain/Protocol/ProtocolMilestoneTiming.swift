import Foundation

public enum ProtocolMilestonePhase: Equatable, Sendable {
    case upcoming
    case imminent
    case reached

    public static func resolve(targetFrame: UInt64, currentFrame: UInt64) -> Self {
        guard currentFrame < targetFrame else { return .reached }
        return targetFrame - currentFrame <= 720 ? .imminent : .upcoming
    }
}

public struct ProtocolMilestoneTiming: Equatable, Sendable {
    public enum Basis: String, Equatable, Sendable {
        case observed = "local observed pace"
        case nominal = "protocol nominal pace"
    }

    public var framesRemaining: UInt64
    public var expectedAt: Date?
    public var earliestAt: Date?
    public var latestAt: Date?
    public var basis: Basis

    public static func estimate(
        targetFrame: UInt64,
        currentFrame: UInt64,
        framesPerMinute: Double?,
        lowerFramesPerMinute: Double? = nil,
        upperFramesPerMinute: Double? = nil,
        now: Date = Date()
    ) -> ProtocolMilestoneTiming {
        let remaining = targetFrame > currentFrame ? targetFrame - currentFrame : 0
        guard remaining > 0 else {
            return ProtocolMilestoneTiming(
                framesRemaining: 0,
                expectedAt: nil,
                earliestAt: nil,
                latestAt: nil,
                basis: framesPerMinute == nil ? .nominal : .observed
            )
        }

        let observed = framesPerMinute.flatMap { $0 > 0.05 ? $0 : nil }
        let center = observed ?? 6.0  // Consensus documents a nominal 10-second frame.
        let low = max(lowerFramesPerMinute ?? center * (observed == nil ? 0.75 : 0.85), 0.05)
        let high = max(upperFramesPerMinute ?? center * (observed == nil ? 1.25 : 1.15), low)
        let expected = now.addingTimeInterval(Double(remaining) / center * 60)
        let earliest = now.addingTimeInterval(Double(remaining) / high * 60)
        let latest = now.addingTimeInterval(Double(remaining) / low * 60)
        return ProtocolMilestoneTiming(
            framesRemaining: remaining,
            expectedAt: expected,
            earliestAt: earliest,
            latestAt: latest,
            basis: observed == nil ? .nominal : .observed
        )
    }
}
