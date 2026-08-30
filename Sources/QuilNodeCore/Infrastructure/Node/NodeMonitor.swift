import Combine
import Foundation

/// The startup observation pipeline deliberately separates process presence
/// from the slower telemetry pass. A missing sample is not evidence that the
/// node is stopped.
public enum NodeObservationPhase: String, Codable, Equatable, Sendable {
    case checkingProcess
    case loadingTelemetry
    case ready

    public var hasDeterminedProcessState: Bool { self != .checkingProcess }
    public var hasLiveTelemetry: Bool { self == .ready }
}

@MainActor
public final class NodeMonitor: ObservableObject {
    @Published public private(set) var snapshot = NodeSnapshot.empty
    @Published public private(set) var observationPhase: NodeObservationPhase = .checkingProcess
    @Published public private(set) var isRefreshing = false
    /// Separates an unobserved startup state from a completed probe that found
    /// no node process. UI must not translate `NodeSnapshot.empty` into a
    /// failure before this becomes true.
    @Published public private(set) var hasCompletedInitialRefresh = false
    @Published public private(set) var processDetectionLatency: TimeInterval?
    @Published public private(set) var lastRefreshError: String?

    private let collector: LocalNodeCollector
    private let refreshInterval: Duration
    private let nodeInfoRefreshInterval: TimeInterval
    private let balanceRefreshInterval: TimeInterval
    private var loopTask: Task<Void, Never>?
    private var balanceTask: Task<Void, Never>?
    private var hasRecoveredHistoricalEvidence = false
    private var refreshInFlight = false
    private var cachedNodeInfo: NodeInfo?
    private var lastNodeInfoRefresh: Date?
    private var lastBalanceRefresh: Date?
    private var lastFrame: UInt64?
    private var lastFrameAdvanceAt: Date?
    private var frameSamples: [(date: Date, frame: UInt64)] = []
    private var cpuTimeSamples: [CPUTimeSample] = []

    public init(
        collector: LocalNodeCollector = LocalNodeCollector(),
        refreshInterval: Duration = .seconds(2),
        nodeInfoRefreshInterval: TimeInterval = 300,
        balanceRefreshInterval: TimeInterval = 60
    ) {
        self.collector = collector
        self.refreshInterval = refreshInterval
        self.nodeInfoRefreshInterval = nodeInfoRefreshInterval
        self.balanceRefreshInterval = balanceRefreshInterval
    }

    deinit {
        loopTask?.cancel()
        balanceTask?.cancel()
    }

    public func start() {
        guard loopTask == nil else { return }
        loopTask = Task { [weak self] in
            if let self, self.snapshot == .empty {
                // Presence is a cheap, authoritative launchd/PID observation.
                // Publish it before log recovery, metrics and identity work so
                // the UI never turns an unobserved bootstrap snapshot into an
                // offline verdict.
                await self.refreshProcessPresence()
                await self.refresh(skipNodeInfo: true)
            }
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh()
                try? await Task.sleep(for: self.refreshInterval)
            }
        }
    }

    public func stop() {
        loopTask?.cancel()
        loopTask = nil
    }

    public func refresh(forceNodeInfo: Bool = false, skipNodeInfo: Bool = false) async {
        guard !refreshInFlight else { return }
        if observationPhase == .checkingProcess {
            await refreshProcessPresence()
        }
        refreshInFlight = true
        if forceNodeInfo { isRefreshing = true }
        defer {
            refreshInFlight = false
            if forceNodeInfo { isRefreshing = false }
        }

        let shouldRefreshNodeInfo =
            !skipNodeInfo
            && (forceNodeInfo
                || cachedNodeInfo == nil
                || lastNodeInfoRefresh.map { Date().timeIntervalSince($0) >= nodeInfoRefreshInterval } != false)
        let shouldRefreshBalance =
            forceNodeInfo
            || lastBalanceRefresh == nil
            || lastBalanceRefresh.map { Date().timeIntervalSince($0) >= balanceRefreshInterval } != false
        // Historical evidence can require bounded reverse scans of large node
        // logs. Never put that work on the first telemetry path; recover it on
        // a later pass after the dashboard is already truthful and usable.
        let shouldRecoverHistoricalEvidence =
            hasCompletedInitialRefresh
            && !hasRecoveredHistoricalEvidence

        let result = await collector.collect(
            cachedSnapshot: snapshot == .empty ? nil : snapshot,
            cachedNodeInfo: cachedNodeInfo,
            refreshNodeInfo: shouldRefreshNodeInfo,
            recoverHistoricalEvidence: shouldRecoverHistoricalEvidence
        )
        var nextSnapshot = result.snapshot
        // A balance read runs independently from the faster telemetry loop.
        // Preserve the newest wallet result if it completed while this
        // telemetry collection was in flight, rather than overwriting it with
        // the older snapshot captured at the start of the collection.
        nextSnapshot.quilBalance = snapshot.quilBalance
        nextSnapshot.quilAccount = snapshot.quilAccount
        nextSnapshot.balanceUpdatedAt = snapshot.balanceUpdatedAt
        nextSnapshot.balanceError = snapshot.balanceError
        nextSnapshot.peerScore = snapshot.peerScore
        nextSnapshot.reachable = snapshot.reachable
        nextSnapshot.allocatedWorkers = snapshot.allocatedWorkers
        nextSnapshot.lastReceivedFrame = snapshot.lastReceivedFrame
        nextSnapshot.lastGlobalHeadFrame = snapshot.lastGlobalHeadFrame
        nextSnapshot.epoch = snapshot.epoch
        nextSnapshot.epochLength = snapshot.epochLength
        nextSnapshot.nextEpochFrame = snapshot.nextEpochFrame
        nextSnapshot.shardAllocations = snapshot.shardAllocations
        nextSnapshot.inboundConnectionsEstablished =
            result.snapshot.inboundConnectionsEstablished
            ?? snapshot.inboundConnectionsEstablished
        nextSnapshot.outboundConnectionsEstablished =
            result.snapshot.outboundConnectionsEstablished
            ?? snapshot.outboundConnectionsEstablished
        nextSnapshot.localWorkerCount =
            result.snapshot.localWorkerCount
            ?? snapshot.localWorkerCount
        updateProcessorUsage(&nextSnapshot)
        updateFrameProgress(&nextSnapshot)
        snapshot = nextSnapshot
        hasCompletedInitialRefresh = true
        observationPhase = .ready
        if shouldRecoverHistoricalEvidence {
            hasRecoveredHistoricalEvidence = true
        }
        if let info = result.nodeInfo {
            cachedNodeInfo = info
            if shouldRefreshNodeInfo { lastNodeInfoRefresh = Date() }
        }
        if shouldRefreshBalance, nextSnapshot.isRunning, balanceTask == nil {
            lastBalanceRefresh = Date()
            balanceTask = Task { [weak self] in
                guard let self else { return }
                defer { balanceTask = nil }
                let result = await collector.collectBalance()
                guard !Task.isCancelled else { return }
                var updated = snapshot
                if let balance = result.balance {
                    updated.quilBalance = balance.amount
                    updated.quilAccount = balance.account
                    updated.balanceUpdatedAt = Date()
                    updated.balanceError = nil
                } else {
                    updated.balanceError = result.error
                }
                snapshot = updated
            }
        }
        lastRefreshError = nil
    }

    private func refreshProcessPresence() async {
        let observation = await collector.observeProcess()
        guard !Task.isCancelled else { return }

        var detected = snapshot
        detected.collectedAt = observation.observedAt
        detected.isRunning = observation.processID != nil
        detected.processID = observation.processID
        snapshot = detected
        processDetectionLatency = observation.latency
        observationPhase = .loadingTelemetry
    }

    /// Converts cumulative process CPU time into a short rolling average. The
    /// primary percentage represents the whole Mac (0...100), while the core
    /// equivalent preserves the per-process detail macOS tools traditionally
    /// expose. Four samples at the normal cadence produce an approximately
    /// six-second window without making brief proving bursts unreadably noisy.
    private func updateProcessorUsage(_ nextSnapshot: inout NodeSnapshot) {
        let logicalCoreCount = max(ProcessInfo.processInfo.activeProcessorCount, 1)
        guard nextSnapshot.isRunning,
            let pid = nextSnapshot.processID,
            let cpuTime = nextSnapshot.processCPUTimeSeconds,
            let sampledAt = nextSnapshot.cpuSampledAt
        else {
            cpuTimeSamples.removeAll()
            nextSnapshot.cpuPercent = nil
            nextSnapshot.cpuCoreEquivalent = nil
            nextSnapshot.cpuSampleWindowSeconds = nil
            return
        }

        if let previous = cpuTimeSamples.last,
            previous.pid != pid || sampledAt <= previous.date || cpuTime < previous.cpuTimeSeconds
        {
            cpuTimeSamples.removeAll()
        }
        if cpuTimeSamples.last?.date != sampledAt {
            cpuTimeSamples.append(
                CPUTimeSample(pid: pid, date: sampledAt, cpuTimeSeconds: cpuTime)
            )
        }
        if cpuTimeSamples.count > 4 {
            cpuTimeSamples.removeFirst(cpuTimeSamples.count - 4)
        }

        if let first = cpuTimeSamples.first,
            let last = cpuTimeSamples.last,
            last.date > first.date,
            last.cpuTimeSeconds >= first.cpuTimeSeconds
        {
            let window = last.date.timeIntervalSince(first.date)
            let coreEquivalent = min(
                max((last.cpuTimeSeconds - first.cpuTimeSeconds) / window, 0),
                Double(logicalCoreCount)
            )
            nextSnapshot.cpuCoreEquivalent = coreEquivalent
            nextSnapshot.cpuPercent = coreEquivalent / Double(logicalCoreCount) * 100
            nextSnapshot.cpuSampleWindowSeconds = window
            return
        }

        // The first refresh has no interval delta yet. Normalize the `ps`
        // decaying average so the dashboard is useful while the live window
        // warms up, then replace it on the next sample.
        if let perCorePercent = nextSnapshot.cpuPercent {
            let coreEquivalent = min(max(perCorePercent / 100, 0), Double(logicalCoreCount))
            nextSnapshot.cpuCoreEquivalent = coreEquivalent
            nextSnapshot.cpuPercent = coreEquivalent / Double(logicalCoreCount) * 100
        }
        nextSnapshot.cpuSampleWindowSeconds = nil
    }

    private func updateFrameProgress(_ nextSnapshot: inout NodeSnapshot) {
        guard nextSnapshot.isRunning, nextSnapshot.frame > 0 else {
            lastFrame = nil
            lastFrameAdvanceAt = nil
            frameSamples.removeAll()
            nextSnapshot.framesPerMinute = nil
            nextSnapshot.lowerFramesPerMinute = nil
            nextSnapshot.upperFramesPerMinute = nil
            return
        }

        let now = nextSnapshot.collectedAt
        if let previous = lastFrame {
            if nextSnapshot.frame != previous {
                lastFrame = nextSnapshot.frame
                lastFrameAdvanceAt = now
                frameSamples.append((now, nextSnapshot.frame))
            }
        } else {
            lastFrame = nextSnapshot.frame
            lastFrameAdvanceAt = now
            frameSamples = [(now, nextSnapshot.frame)]
        }

        frameSamples.removeAll { now.timeIntervalSince($0.date) > 5 * 60 }
        nextSnapshot.frameLastAdvancedAt = lastFrameAdvanceAt
        guard let first = frameSamples.first,
            let last = frameSamples.last,
            last.frame >= first.frame,
            last.date.timeIntervalSince(first.date) >= 120
        else {
            // Short windows are dominated by batched status writes and catch-up
            // bursts. Keep the public 10-second protocol fallback until two
            // minutes of local evidence exists instead of publishing a wildly
            // optimistic countdown after every app restart.
            nextSnapshot.framesPerMinute = nil
            nextSnapshot.lowerFramesPerMinute = nil
            nextSnapshot.upperFramesPerMinute = nil
            return
        }

        let totalWindow = last.date.timeIntervalSince(first.date)
        nextSnapshot.framesPerMinute = Double(last.frame - first.frame) / totalWindow * 60

        var windowRates: [Double] = []
        for earlierIndex in frameSamples.indices {
            for laterIndex in frameSamples.indices where laterIndex > earlierIndex {
                let earlier = frameSamples[earlierIndex]
                let later = frameSamples[laterIndex]
                let seconds = later.date.timeIntervalSince(earlier.date)
                guard seconds >= 60, later.frame >= earlier.frame else { continue }
                let rate = Double(later.frame - earlier.frame) / seconds * 60
                if rate > 0.05, rate < 120 { windowRates.append(rate) }
            }
        }
        if windowRates.count >= 3 {
            let sorted = windowRates.sorted()
            nextSnapshot.lowerFramesPerMinute = percentile(sorted, 0.25)
            nextSnapshot.upperFramesPerMinute = percentile(sorted, 0.75)
        } else {
            nextSnapshot.lowerFramesPerMinute = nil
            nextSnapshot.upperFramesPerMinute = nil
        }
    }

    private func percentile(_ sorted: [Double], _ fraction: Double) -> Double? {
        guard !sorted.isEmpty else { return nil }
        let position = min(max(fraction, 0), 1) * Double(sorted.count - 1)
        let lower = Int(position.rounded(.down))
        let upper = Int(position.rounded(.up))
        guard lower != upper else { return sorted[lower] }
        let weight = position - Double(lower)
        return sorted[lower] * (1 - weight) + sorted[upper] * weight
    }
}

private struct CPUTimeSample {
    let pid: Int32
    let date: Date
    let cpuTimeSeconds: Double
}
