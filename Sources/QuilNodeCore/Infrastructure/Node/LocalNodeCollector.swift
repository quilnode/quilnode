import Foundation
import QuilNodeShared

public struct LocalNodeCollector: Sendable {
    public let paths: LocalNodePaths

    public init(paths: LocalNodePaths = LocalNodePaths()) {
        self.paths = paths
    }

    /// Returns the managed process state without touching logs, metrics,
    /// identity RPCs or historical evidence. This is the launch-time fast path
    /// and should normally complete in a fraction of a second.
    public func observeProcess() async -> NodeProcessObservation {
        await Task.detached(priority: .userInitiated) {
            let startedAt = ContinuousClock.now
            let pid = runningNodePID()
            return NodeProcessObservation(
                processID: pid,
                observedAt: Date(),
                latency: startedAt.duration(to: .now).timeInterval
            )
        }.value
    }

    public func collect(
        cachedSnapshot: NodeSnapshot? = nil,
        cachedNodeInfo: NodeInfo? = nil,
        refreshNodeInfo: Bool = true,
        recoverHistoricalEvidence: Bool = true
    ) async -> CollectionResult {
        await Task.detached(priority: .utility) {
            collectSynchronously(
                cachedSnapshot: cachedSnapshot,
                cachedNodeInfo: cachedNodeInfo,
                refreshNodeInfo: refreshNodeInfo,
                recoverHistoricalEvidence: recoverHistoricalEvidence
            )
        }.value
    }

    public func collectBalance() async -> BalanceCollectionResult {
        await Task.detached(priority: .utility) {
            let read = PrivilegedServiceClient.readBalance()
            return BalanceCollectionResult(balance: read.balance, error: read.error)
        }.value
    }

    public func collectProverTelemetry() async -> ProverTelemetryCollectionResult {
        await Task.detached(priority: .utility) {
            let read = PrivilegedServiceClient.readProverTelemetry()
            return ProverTelemetryCollectionResult(
                telemetry: read.telemetry,
                error: read.error
            )
        }.value
    }

    private func collectSynchronously(
        cachedSnapshot: NodeSnapshot?,
        cachedNodeInfo: NodeInfo?,
        refreshNodeInfo: Bool,
        recoverHistoricalEvidence: Bool
    ) -> CollectionResult {
        let now = Date()
        let pid = runningNodePID()
        let logModified = fileModifiedAt(paths.errorLog)
        let logChanged = cachedSnapshot == nil || cachedSnapshot?.logLastModifiedAt != logModified
        let logText = logChanged ? (readTail(paths.errorLog, maximumBytes: 256_000) ?? "") : ""
        let status = logChanged ? (NodeStatusParser.latestStatus(in: logText) ?? [:]) : [:]
        let recentRewardCredit = logChanged ? latestRewardCredit(in: logText) : nil
        let protocolObservations =
            logChanged
            ? ProtocolEventLogParser.observations(in: logText)
            : [:]
        let chainProgressEvidence =
            logChanged
            ? ChainProgressLogParser.parse(logText, now: now)
            : cachedSnapshot?.chainProgressEvidence
        let liveArchiveEndpointCount =
            logChanged
            ? ArchiveEndpointLogParser.latestCount(in: logText)
            : nil
        let archiveEndpointCount =
            liveArchiveEndpointCount
            ?? cachedSnapshot?.archiveEndpointCount
            ?? (recoverHistoricalEvidence ? readLatestArchiveEndpointCount(paths.errorLog) : nil)
        let rewardCredit =
            recentRewardCredit
            // Historical recovery is intentionally a cold-start operation.
            // Re-scanning a large node log every two seconds when no credit
            // exists can consume an entire CPU core without adding new data.
            ?? (recoverHistoricalEvidence ? readLatestRewardCredit(paths.errorLog) : nil)
        let info = refreshNodeInfo ? readNodeInfo() : cachedNodeInfo
        // Registry events are the official node's materialized consensus view.
        // Parse the live tail on every log change so seniority can move without
        // an app relaunch; only use the bounded reverse scan for cold recovery.
        let liveRegistryEvidence = logChanged ? LocalRegistryParser.latest(in: logText) : nil
        let registryEvidence =
            liveRegistryEvidence
            ?? (recoverHistoricalEvidence ? readLatestRegistryEvidence(paths.errorLog) : nil)
        let process = pid.flatMap(readProcessStats)
        let metricsText = pid == nil ? "" : readMetrics()
        let metricPeers = NodeMetricsParser.value("libp2p_connected_peers", in: metricsText).map(Int.init)
        let inboundConnections = NodeMetricsParser.value(
            "libp2p_connections_established_total",
            labels: ["direction": "Inbound"],
            in: metricsText
        ).map(UInt64.init)
        let outboundConnections = NodeMetricsParser.value(
            "libp2p_connections_established_total",
            labels: ["direction": "Outbound"],
            in: metricsText
        ).map(UInt64.init)
        let localWorkerCount =
            logChanged
            ? WorkerRuntimeParser.localThreadWorkerCount(in: logText)
            : cachedSnapshot?.localWorkerCount

        func statusInt(_ key: String, fallback: Int) -> Int {
            guard logChanged else { return fallback }
            return NodeStatusParser.int(status, key)
        }

        func statusUInt64(_ key: String, fallback: UInt64) -> UInt64 {
            guard logChanged else { return fallback }
            return NodeStatusParser.uint64(status, key)
        }

        let diagnosticSeniority = info?.seniority ?? 0
        let seniority: Int64
        let previousSeniority: Int64?
        let seniorityUpdatedAt: Date?
        let seniorityEvidenceSource: SeniorityEvidenceSource?
        let seniorityEvidenceKind: SeniorityEvidenceKind?
        if let registryEvidence {
            seniority = registryEvidence.seniority
            previousSeniority = registryEvidence.previousSeniority
            seniorityUpdatedAt = registryEvidence.observedAt ?? now
            seniorityEvidenceSource = .consensusRegistry
            seniorityEvidenceKind = registryEvidence.kind
        } else if diagnosticSeniority > 0 {
            seniority = diagnosticSeniority
            previousSeniority =
                cachedSnapshot?.seniority == diagnosticSeniority
                ? cachedSnapshot?.previousSeniority
                : cachedSnapshot?.seniority
            seniorityUpdatedAt =
                diagnosticSeniority == cachedSnapshot?.seniority
                ? cachedSnapshot?.seniorityUpdatedAt
                : now
            seniorityEvidenceSource = .nodeDiagnostic
            seniorityEvidenceKind = .diagnostic
        } else {
            seniority = cachedSnapshot?.seniority ?? 0
            previousSeniority = cachedSnapshot?.previousSeniority
            seniorityUpdatedAt = cachedSnapshot?.seniorityUpdatedAt
            seniorityEvidenceSource = cachedSnapshot?.seniorityEvidenceSource
            seniorityEvidenceKind = cachedSnapshot?.seniorityEvidenceKind
        }

        var snapshot = NodeSnapshot(
            collectedAt: now,
            isRunning: pid != nil,
            processID: pid,
            version: info?.version,
            peerID: info?.peerID,
            legacyPeerID: info?.legacyPeerID,
            proverAddress: info?.proverAddress ?? registryEvidence?.proverAddress,
            quilBalance: cachedSnapshot?.quilBalance,
            quilAccount: cachedSnapshot?.quilAccount,
            balanceUpdatedAt: cachedSnapshot?.balanceUpdatedAt,
            balanceError: cachedSnapshot?.balanceError,
            rewardBalanceSubunits: rewardCredit?.balanceSubunits ?? cachedSnapshot?.rewardBalanceSubunits,
            lastRewardCreditFrame: rewardCredit?.frame ?? cachedSnapshot?.lastRewardCreditFrame,
            lastRewardCreditAt: rewardCredit?.date ?? cachedSnapshot?.lastRewardCreditAt,
            proverStatusUpdatedAt: registryEvidence == nil
                ? cachedSnapshot?.proverStatusUpdatedAt
                : (registryEvidence?.observedAt ?? now),
            proverStatusError: nil,
            seniority: seniority,
            previousSeniority: previousSeniority,
            seniorityUpdatedAt: seniorityUpdatedAt,
            seniorityEvidenceSource: seniorityEvidenceSource,
            seniorityEvidenceKind: seniorityEvidenceKind,
            peerScore: cachedSnapshot?.peerScore,
            reachable: cachedSnapshot?.reachable,
            allocatedWorkers: cachedSnapshot?.allocatedWorkers ?? 0,
            lastReceivedFrame: cachedSnapshot?.lastReceivedFrame ?? 0,
            lastGlobalHeadFrame: cachedSnapshot?.lastGlobalHeadFrame ?? 0,
            epoch: cachedSnapshot?.epoch ?? 0,
            epochLength: cachedSnapshot?.epochLength ?? 720,
            nextEpochFrame: cachedSnapshot?.nextEpochFrame ?? 0,
            shardAllocations: cachedSnapshot?.shardAllocations ?? [],
            networkShards: cachedSnapshot?.networkShards,
            networkShardSummary: cachedSnapshot?.networkShardSummary,
            frame: max(statusUInt64("frame", fallback: cachedSnapshot?.frame ?? 0), info?.frame ?? 0),
            peers: metricPeers ?? statusInt("peers", fallback: cachedSnapshot?.peers ?? 0),
            inboundConnectionsEstablished: inboundConnections ?? cachedSnapshot?.inboundConnectionsEstablished,
            outboundConnectionsEstablished: outboundConnections ?? cachedSnapshot?.outboundConnectionsEstablished,
            localWorkerCount: localWorkerCount ?? cachedSnapshot?.localWorkerCount,
            archivePeers: statusInt("archive_peers", fallback: cachedSnapshot?.archivePeers ?? 0),
            archiveEndpointCount: archiveEndpointCount,
            pendingJoins: statusInt("pending_joins", fallback: cachedSnapshot?.pendingJoins ?? 0),
            activeShards: statusInt("active_shards", fallback: cachedSnapshot?.activeShards ?? 0),
            totalAllocations: statusInt(
                "total_allocations",
                fallback: max(cachedSnapshot?.totalAllocations ?? 0, registryEvidence?.allocations ?? 0)
            ),
            framesReceived: statusUInt64("frames_received", fallback: cachedSnapshot?.framesReceived ?? 0),
            routerDrops: statusUInt64("router_drops", fallback: cachedSnapshot?.routerDrops ?? 0),
            cpuPercent: process?.cpuPercent,
            processCPUTimeSeconds: process?.cpuTimeSeconds,
            cpuSampledAt: process?.sampledAt,
            memoryMB: process?.memoryMB,
            processUptime: process?.elapsed,
            logLastModifiedAt: logModified,
            metricsUpdatedAt: metricsText.isEmpty ? cachedSnapshot?.metricsUpdatedAt : now,
            frameLastAdvancedAt: cachedSnapshot?.frameLastAdvancedAt,
            framesPerMinute: cachedSnapshot?.framesPerMinute,
            lowerFramesPerMinute: cachedSnapshot?.lowerFramesPerMinute,
            upperFramesPerMinute: cachedSnapshot?.upperFramesPerMinute,
            observedProtocolMilestones: (cachedSnapshot?.observedProtocolMilestones ?? [:])
                .merging(protocolObservations) { _, newest in newest },
            chainProgressEvidence: chainProgressEvidence,
            recentWarnings: logChanged
                ? NodeStatusParser.recentWarnings(in: logText)
                : (cachedSnapshot?.recentWarnings ?? [])
        )

        if logText.isEmpty && pid != nil {
            snapshot.recentWarnings = ["The node is running, but its local status log could not be read."]
        }

        return CollectionResult(snapshot: snapshot, nodeInfo: info)
    }

}
