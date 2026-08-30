import Foundation
import QuilNodeShared

public struct LocalNodePaths: Sendable {
    public var nodeDirectory: URL
    public var nodeBinary: URL
    public var errorLog: URL

    public init(
        nodeDirectory: URL = URL(fileURLWithPath: "/opt/quilibrium/node", isDirectory: true),
        nodeBinary: URL = URL(fileURLWithPath: "/opt/quilibrium/node/quilibrium-node"),
        errorLog: URL = URL(fileURLWithPath: "/opt/quilibrium/node/node-error.log")
    ) {
        self.nodeDirectory = nodeDirectory
        self.nodeBinary = nodeBinary
        self.errorLog = errorLog
    }
}

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

    private func runningNodePID() -> Int32? {
        let service = run(
            executable: URL(fileURLWithPath: "/bin/launchctl"),
            arguments: ["print", "system/com.quilibrium.node"],
            timeout: 2
        )
        if service.exitCode == 0,
            let regex = try? NSRegularExpression(pattern: #"(?m)^\s*pid = ([0-9]+)\s*$"#),
            let match = regex.firstMatch(
                in: service.output,
                range: NSRange(service.output.startIndex..., in: service.output)
            ),
            let range = Range(match.range(at: 1), in: service.output),
            let pid = Int32(service.output[range])
        {
            return pid
        }

        // Fallback for a manually started node. Match the exact daemon command
        // so short-lived `--metrics` and `--node-info` clients are never
        // mistaken for the service process.
        let fallback = run(
            executable: URL(fileURLWithPath: "/usr/bin/pgrep"),
            arguments: ["-f", "^/opt/quilibrium/node/quilibrium-node$"],
            timeout: 2
        )
        guard fallback.exitCode == 0 else { return nil }
        return fallback.output.split(whereSeparator: \.isWhitespace).compactMap { Int32($0) }.first
    }

    private func readNodeInfo() -> NodeInfo? {
        if let privilegedInfo = PrivilegedServiceClient.readNodeInfo() {
            return privilegedInfo
        }
        guard FileManager.default.isExecutableFile(atPath: paths.nodeBinary.path) else {
            return nil
        }
        let result = run(
            executable: paths.nodeBinary,
            arguments: ["--node-info"],
            currentDirectory: paths.nodeDirectory,
            timeout: 15
        )
        var info = NodeInfoParser.parse(result.output)
        let peerResult = run(
            executable: paths.nodeBinary,
            arguments: ["--peer-info"],
            currentDirectory: paths.nodeDirectory,
            timeout: 10
        )
        let peerInfo = NodeInfoParser.parse(peerResult.output)
        info.legacyPeerID = peerInfo.legacyPeerID
        return info.version == nil && info.peerID == nil && info.proverAddress == nil ? nil : info
    }

    private func readMetrics() -> String {
        // `.25` exposes metrics over the node's loopback diagnostic endpoint,
        // which is readable without opening the private config directory. Use
        // that direct local path first so newly added upstream metrics are not
        // hidden by an older installed helper response schema.
        let direct = run(
            executable: paths.nodeBinary,
            arguments: ["--metrics"],
            currentDirectory: paths.nodeDirectory,
            timeout: 3
        ).output
        if !direct.isEmpty,
            direct.contains("libp2p_connected_peers")
        {
            return direct
        }
        if let metrics = PrivilegedServiceClient.readMetrics(), !metrics.isEmpty {
            return metrics
        }
        return direct
    }

    private func readProcessStats(pid: Int32) -> ProcessStats? {
        let result = run(
            executable: URL(fileURLWithPath: "/bin/ps"),
            arguments: ["-p", String(pid), "-o", "%cpu=,rss=,etime=,time="],
            timeout: 2
        )
        guard result.exitCode == 0 else { return nil }
        let fields = result.output.split(whereSeparator: \.isWhitespace)
        guard fields.count >= 4 else { return nil }
        let cpu = Double(fields[0])
        let rssKB = Double(fields[1])
        return ProcessStats(
            cpuPercent: cpu,
            cpuTimeSeconds: ProcessCPUTimeParser.parse(String(fields[3])),
            sampledAt: Date(),
            memoryMB: rssKB.map { $0 / 1024 },
            elapsed: String(fields[2])
        )
    }

    private func readTail(_ url: URL, maximumBytes: UInt64) -> String? {
        guard
            let data = try? BoundedLocalData.readTail(
                from: url,
                maximumFileBytes: .max,
                maximumTailBytes: Int(maximumBytes),
                allowGrowth: true
            )
        else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    private func readLatestRegistryEvidence(_ url: URL) -> LocalRegistryEvidence? {
        // A busy prover can emit tens of megabytes per hour. This path runs
        // only once per app launch, and stops as soon as it finds evidence.
        return try? BoundedLocalData.firstMatchInReverseTail(
            from: url,
            maximumFileBytes: .max,
            maximumScanBytes: 128 * 1_024 * 1_024,
            chunkBytes: 8 * 1_024 * 1_024
        ) { data in
            LocalRegistryParser.latest(in: String(decoding: data, as: UTF8.self))
        }
    }

    private func readLatestRewardCredit(_ url: URL) -> RewardCreditEvidence? {
        return try? BoundedLocalData.firstMatchInReverseTail(
            from: url,
            maximumFileBytes: .max,
            maximumScanBytes: 32 * 1_024 * 1_024,
            chunkBytes: 8 * 1_024 * 1_024
        ) { data in
            latestRewardCredit(in: String(decoding: data, as: UTF8.self))
        }
    }

    private func readLatestArchiveEndpointCount(_ url: URL) -> Int? {
        return try? BoundedLocalData.firstMatchInReverseTail(
            from: url,
            maximumFileBytes: .max,
            maximumScanBytes: 8 * 1_024 * 1_024,
            chunkBytes: 1 * 1_024 * 1_024
        ) { data in
            ArchiveEndpointLogParser.latestCount(in: String(decoding: data, as: UTF8.self))
        }
    }

    private func latestRewardCredit(in text: String) -> RewardCreditEvidence? {
        for line in text.split(separator: "\n").reversed() {
            let value = String(line)
            guard value.contains("reward credited to local prover") else { continue }
            guard let frame = capture(#"\"frame\":([0-9]+)"#, in: value).flatMap(UInt64.init),
                let balance = capture(#"\"new_balance\":\"?([0-9]+)\"?"#, in: value)
            else {
                continue
            }
            let timestamp = value.split(separator: "\t", maxSplits: 1).first.map(String.init)
            let date = timestamp.flatMap { ISO8601DateFormatter().date(from: $0) }
            return RewardCreditEvidence(frame: frame, balanceSubunits: balance, date: date)
        }
        return nil
    }

    private func capture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(
                in: text,
                range: NSRange(text.startIndex..., in: text)
            ),
            let range = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return String(text[range])
    }

    private func fileModifiedAt(_ url: URL) -> Date? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attributes?[.modificationDate] as? Date
    }

    private func run(
        executable: URL,
        arguments: [String],
        currentDirectory: URL? = nil,
        timeout: TimeInterval
    ) -> CommandResult {
        let result = BoundedCommandRunner.run(
            executable: executable.path,
            arguments: arguments,
            currentDirectory: currentDirectory,
            timeout: timeout
        )
        return CommandResult(
            output: result.output,
            exitCode: result.exitCode
        )
    }
}
