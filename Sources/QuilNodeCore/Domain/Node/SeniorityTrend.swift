import Foundation

public enum SeniorityTrendDirection: Equatable, Sendable {
    case collecting
    case increased
    case unchanged
    case decreased
}

public struct SenioritySample: Equatable, Sendable {
    public let value: Int64
    public let observedAt: Date

    public init(value: Int64, observedAt: Date) {
        self.value = value
        self.observedAt = observedAt
    }
}

/// A conservative trend derived only from source-backed consensus samples.
/// It never extrapolates the protocol's per-frame accrual rule.
public struct SeniorityTrend: Equatable, Sendable {
    public let direction: SeniorityTrendDirection
    public let delta: Int64
    public let comparisonStartedAt: Date?
    public let latestObservedAt: Date?

    public init(
        direction: SeniorityTrendDirection,
        delta: Int64,
        comparisonStartedAt: Date?,
        latestObservedAt: Date?
    ) {
        self.direction = direction
        self.delta = delta
        self.comparisonStartedAt = comparisonStartedAt
        self.latestObservedAt = latestObservedAt
    }

    public static func evaluate(
        currentValue: Int64,
        previousValue: Int64?,
        currentObservedAt: Date?,
        samples: [SenioritySample],
        now: Date = Date()
    ) -> SeniorityTrend {
        guard currentValue > 0 else {
            return SeniorityTrend(
                direction: .collecting,
                delta: 0,
                comparisonStartedAt: nil,
                latestObservedAt: nil
            )
        }

        let retentionCutoff = now.addingTimeInterval(-7 * 24 * 60 * 60)
        var observations = samples.filter {
            $0.value > 0 && $0.observedAt >= retentionCutoff
        }
        let currentDate = currentObservedAt ?? now
        if let previousValue,
            previousValue > 0,
            previousValue != currentValue,
            currentDate >= retentionCutoff
        {
            observations.append(
                SenioritySample(
                    value: previousValue,
                    observedAt: currentDate.addingTimeInterval(-0.001)
                )
            )
        }
        observations.append(
            SenioritySample(value: currentValue, observedAt: currentDate)
        )
        observations.sort { $0.observedAt < $1.observedAt }

        var distinct: [SenioritySample] = []
        for observation in observations {
            if distinct.last?.observedAt == observation.observedAt {
                distinct[distinct.count - 1] = observation
            } else if distinct.last?.value != observation.value {
                distinct.append(observation)
            }
        }

        guard let first = distinct.first, let latest = distinct.last else {
            return SeniorityTrend(
                direction: .collecting,
                delta: 0,
                comparisonStartedAt: nil,
                latestObservedAt: currentObservedAt
            )
        }

        let delta = latest.value - first.value
        let direction: SeniorityTrendDirection
        if delta > 0 {
            direction = .increased
        } else if delta < 0 {
            direction = .decreased
        } else {
            direction =
                now.timeIntervalSince(first.observedAt) >= 60 * 60
                ? .unchanged
                : .collecting
        }
        return SeniorityTrend(
            direction: direction,
            delta: delta,
            comparisonStartedAt: first.observedAt,
            latestObservedAt: latest.observedAt
        )
    }
}
