import Foundation

/// Converts cumulative process CPU time into a bounded, whole-machine load.
/// State lives here so `NodeMonitor` only orchestrates collection and publish.
struct NodeProcessorUsageSampler {
    private struct Sample {
        let pid: Int32
        let date: Date
        let cpuTimeSeconds: Double
    }

    private let logicalCoreCount: Int
    private let maximumSampleCount: Int
    private var samples: [Sample] = []

    init(
        logicalCoreCount: Int = ProcessInfo.processInfo.activeProcessorCount,
        maximumSampleCount: Int = 4
    ) {
        self.logicalCoreCount = max(logicalCoreCount, 1)
        self.maximumSampleCount = max(maximumSampleCount, 2)
    }

    mutating func apply(to snapshot: inout NodeSnapshot) {
        guard snapshot.isRunning,
            let pid = snapshot.processID,
            let cpuTime = snapshot.processCPUTimeSeconds,
            let sampledAt = snapshot.cpuSampledAt
        else {
            reset(snapshot: &snapshot)
            return
        }

        if let previous = samples.last,
            previous.pid != pid || sampledAt <= previous.date || cpuTime < previous.cpuTimeSeconds
        {
            samples.removeAll()
        }
        if samples.last?.date != sampledAt {
            samples.append(Sample(pid: pid, date: sampledAt, cpuTimeSeconds: cpuTime))
        }
        if samples.count > maximumSampleCount {
            samples.removeFirst(samples.count - maximumSampleCount)
        }

        if let first = samples.first,
            let last = samples.last,
            last.date > first.date,
            last.cpuTimeSeconds >= first.cpuTimeSeconds
        {
            let window = last.date.timeIntervalSince(first.date)
            let coreEquivalent = min(
                max((last.cpuTimeSeconds - first.cpuTimeSeconds) / window, 0),
                Double(logicalCoreCount)
            )
            snapshot.cpuCoreEquivalent = coreEquivalent
            snapshot.cpuPercent = coreEquivalent / Double(logicalCoreCount) * 100
            snapshot.cpuSampleWindowSeconds = window
            return
        }

        // The first sample has no interval delta. Normalize the `ps` decaying
        // average until a local interval can replace it on the next sample.
        if let perCorePercent = snapshot.cpuPercent {
            let coreEquivalent = min(max(perCorePercent / 100, 0), Double(logicalCoreCount))
            snapshot.cpuCoreEquivalent = coreEquivalent
            snapshot.cpuPercent = coreEquivalent / Double(logicalCoreCount) * 100
        }
        snapshot.cpuSampleWindowSeconds = nil
    }

    private mutating func reset(snapshot: inout NodeSnapshot) {
        samples.removeAll()
        snapshot.cpuPercent = nil
        snapshot.cpuCoreEquivalent = nil
        snapshot.cpuSampleWindowSeconds = nil
    }
}
