import Foundation

/// Maintains the bounded observation window used for local frame-rate and ETA
/// evidence. Short windows intentionally remain unknown because batched status
/// writes and catch-up bursts would otherwise produce misleading estimates.
struct NodeFrameProgressTracker {
    private struct Sample {
        let date: Date
        let frame: UInt64
    }

    private let retentionInterval: TimeInterval
    private let minimumRateWindow: TimeInterval
    private var lastFrame: UInt64?
    private var lastAdvanceAt: Date?
    private var samples: [Sample] = []

    init(
        retentionInterval: TimeInterval = 5 * 60,
        minimumRateWindow: TimeInterval = 120
    ) {
        self.retentionInterval = retentionInterval
        self.minimumRateWindow = minimumRateWindow
    }

    mutating func apply(to snapshot: inout NodeSnapshot) {
        guard snapshot.isRunning, snapshot.frame > 0 else {
            reset(snapshot: &snapshot)
            return
        }

        let now = snapshot.collectedAt
        if let previous = lastFrame {
            if snapshot.frame != previous {
                lastFrame = snapshot.frame
                lastAdvanceAt = now
                samples.append(Sample(date: now, frame: snapshot.frame))
            }
        } else {
            lastFrame = snapshot.frame
            lastAdvanceAt = now
            samples = [Sample(date: now, frame: snapshot.frame)]
        }

        let cutoff = now.addingTimeInterval(-retentionInterval)
        samples.removeAll { $0.date < cutoff }
        snapshot.frameLastAdvancedAt = lastAdvanceAt
        guard let first = samples.first,
            let last = samples.last,
            last.frame >= first.frame,
            last.date.timeIntervalSince(first.date) >= minimumRateWindow
        else {
            clearRate(on: &snapshot)
            return
        }

        let totalWindow = last.date.timeIntervalSince(first.date)
        snapshot.framesPerMinute = Double(last.frame - first.frame) / totalWindow * 60

        let rates = pairwiseRates().sorted()
        if rates.count >= 3 {
            snapshot.lowerFramesPerMinute = percentile(rates, fraction: 0.25)
            snapshot.upperFramesPerMinute = percentile(rates, fraction: 0.75)
        } else {
            snapshot.lowerFramesPerMinute = nil
            snapshot.upperFramesPerMinute = nil
        }
    }

    private func pairwiseRates() -> [Double] {
        var rates: [Double] = []
        for earlierIndex in samples.indices {
            for laterIndex in samples.indices where laterIndex > earlierIndex {
                let earlier = samples[earlierIndex]
                let later = samples[laterIndex]
                let seconds = later.date.timeIntervalSince(earlier.date)
                guard seconds >= 60, later.frame >= earlier.frame else { continue }
                let rate = Double(later.frame - earlier.frame) / seconds * 60
                if rate > 0.05, rate < 120 { rates.append(rate) }
            }
        }
        return rates
    }

    private func percentile(_ sorted: [Double], fraction: Double) -> Double? {
        guard !sorted.isEmpty else { return nil }
        let position = min(max(fraction, 0), 1) * Double(sorted.count - 1)
        let lower = Int(position.rounded(.down))
        let upper = Int(position.rounded(.up))
        guard lower != upper else { return sorted[lower] }
        let weight = position - Double(lower)
        return sorted[lower] * (1 - weight) + sorted[upper] * weight
    }

    private mutating func reset(snapshot: inout NodeSnapshot) {
        lastFrame = nil
        lastAdvanceAt = nil
        samples.removeAll()
        snapshot.frameLastAdvancedAt = nil
        clearRate(on: &snapshot)
    }

    private func clearRate(on snapshot: inout NodeSnapshot) {
        snapshot.framesPerMinute = nil
        snapshot.lowerFramesPerMinute = nil
        snapshot.upperFramesPerMinute = nil
    }
}
