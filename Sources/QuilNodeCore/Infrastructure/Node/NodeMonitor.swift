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
    private let proverTelemetryRefreshInterval: TimeInterval
    private var loopTask: Task<Void, Never>?
    private var balanceTask: Task<Void, Never>?
    private var proverTelemetryTask: Task<Void, Never>?
    private var hasRecoveredHistoricalEvidence = false
    private var refreshInFlight = false
    private var cachedNodeInfo: NodeInfo?
    private var lastNodeInfoRefresh: Date?
    private var lastBalanceRefresh: Date?
    private var lastProverTelemetryRefresh: Date?
    private var processorUsageSampler = NodeProcessorUsageSampler()
    private var frameProgressTracker = NodeFrameProgressTracker()

    public init(
        collector: LocalNodeCollector = LocalNodeCollector(),
        refreshInterval: Duration = .seconds(2),
        nodeInfoRefreshInterval: TimeInterval = 300,
        balanceRefreshInterval: TimeInterval = 60,
        proverTelemetryRefreshInterval: TimeInterval = 60
    ) {
        self.collector = collector
        self.refreshInterval = refreshInterval
        self.nodeInfoRefreshInterval = nodeInfoRefreshInterval
        self.balanceRefreshInterval = balanceRefreshInterval
        self.proverTelemetryRefreshInterval = proverTelemetryRefreshInterval
    }

    deinit {
        loopTask?.cancel()
        balanceTask?.cancel()
        proverTelemetryTask?.cancel()
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
        let shouldRefreshProverTelemetry =
            forceNodeInfo
            || lastProverTelemetryRefresh == nil
            || lastProverTelemetryRefresh.map {
                Date().timeIntervalSince($0) >= proverTelemetryRefreshInterval
            } != false
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
        nextSnapshot.networkShardSummary = snapshot.networkShardSummary
        nextSnapshot.inboundConnectionsEstablished =
            result.snapshot.inboundConnectionsEstablished
            ?? snapshot.inboundConnectionsEstablished
        nextSnapshot.outboundConnectionsEstablished =
            result.snapshot.outboundConnectionsEstablished
            ?? snapshot.outboundConnectionsEstablished
        nextSnapshot.localWorkerCount =
            result.snapshot.localWorkerCount
            ?? snapshot.localWorkerCount
        processorUsageSampler.apply(to: &nextSnapshot)
        frameProgressTracker.apply(to: &nextSnapshot)
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
        if shouldRefreshProverTelemetry,
            nextSnapshot.isRunning,
            proverTelemetryTask == nil
        {
            lastProverTelemetryRefresh = Date()
            proverTelemetryTask = Task { [weak self] in
                guard let self else { return }
                defer { proverTelemetryTask = nil }
                let result = await collector.collectProverTelemetry()
                guard !Task.isCancelled else { return }
                var updated = snapshot
                if let telemetry = result.telemetry {
                    applyProverTelemetry(telemetry, to: &updated)
                    updated.proverStatusError = nil
                } else {
                    updated.proverStatusError = result.error
                }
                snapshot = updated
            }
        }
        lastRefreshError = nil
    }

    private func applyProverTelemetry(
        _ telemetry: LocalProverTelemetry,
        to snapshot: inout NodeSnapshot
    ) {
        let status = telemetry.status
        snapshot.peerScore = status.peerScore
        snapshot.reachable = status.reachable
        snapshot.allocatedWorkers = status.allocatedWorkers
        snapshot.lastReceivedFrame = status.lastReceivedFrame
        snapshot.lastGlobalHeadFrame = status.lastGlobalHeadFrame
        snapshot.epoch = status.epoch
        snapshot.epochLength = status.epochLength
        snapshot.nextEpochFrame = status.nextEpochFrame
        snapshot.shardAllocations = status.allocations
        snapshot.networkShardSummary = telemetry.networkSummary
        snapshot.proverStatusUpdatedAt = telemetry.observedAt

        let statuses = status.allocations.map { $0.status.lowercased() }
        snapshot.activeShards = statuses.count { $0 == "active" }
        snapshot.pendingJoins = statuses.count { $0 == "joining" }
        snapshot.totalAllocations = status.allocations.count
        if status.runningWorkers > 0 {
            snapshot.localWorkerCount = status.runningWorkers
        }
        snapshot.frame = max(
            max(snapshot.frame, status.lastReceivedFrame),
            telemetry.networkSummary?.frame ?? 0
        )
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

}
