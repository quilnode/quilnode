import Foundation

/// A bounded, privacy-safe summary of archive synchronization messages emitted
/// by the local node. Raw endpoints, roots, paths, and identifiers never leave
/// the collector; presentation code receives counts and frame numbers only.
public struct ChainProgressEvidence: Codable, Equatable, Sendable {
    public var observedAt: Date
    public var archiveConnections: Int
    public var archiveRPCStandby: Int
    public var archiveConnectionFailures: Int
    public var archiveAtLocalHead: Int
    public var archiveAheadOfLocalHead: Int
    public var zeroShardSizeResponses: Int
    public var finalizedRootUnavailable: Int
    public var vertexRootMismatches: Int
    public var archiveAnchorRejections: Int
    public var highestArchiveFrame: UInt64?

    public init(
        observedAt: Date,
        archiveConnections: Int = 0,
        archiveRPCStandby: Int = 0,
        archiveConnectionFailures: Int = 0,
        archiveAtLocalHead: Int = 0,
        archiveAheadOfLocalHead: Int = 0,
        zeroShardSizeResponses: Int = 0,
        finalizedRootUnavailable: Int = 0,
        vertexRootMismatches: Int = 0,
        archiveAnchorRejections: Int = 0,
        highestArchiveFrame: UInt64? = nil
    ) {
        self.observedAt = observedAt
        self.archiveConnections = archiveConnections
        self.archiveRPCStandby = archiveRPCStandby
        self.archiveConnectionFailures = archiveConnectionFailures
        self.archiveAtLocalHead = archiveAtLocalHead
        self.archiveAheadOfLocalHead = archiveAheadOfLocalHead
        self.zeroShardSizeResponses = zeroShardSizeResponses
        self.finalizedRootUnavailable = finalizedRootUnavailable
        self.vertexRootMismatches = vertexRootMismatches
        self.archiveAnchorRejections = archiveAnchorRejections
        self.highestArchiveFrame = highestArchiveFrame
    }

    public var recoverySignalCount: Int {
        zeroShardSizeResponses
            + finalizedRootUnavailable
            + vertexRootMismatches
            + archiveAnchorRejections
    }
}

/// Reads the size of the node's archive RPC pool from its own structured log.
/// This remains separate from `archive_peers`, which counts PeerInfo
/// advertisements and says nothing about current RPC reachability.
public enum ArchiveEndpointLogParser {
    public static func latestCount(in text: String) -> Int? {
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true).reversed() {
            let line = String(rawLine)
            if line.contains("reconcile: no reachable peer holds the finalized prover root"),
                let count = integer(named: "peers", in: line)
            {
                return count
            }
            if line.contains("archive endpoint added"),
                let count = integer(named: "total", in: line)
            {
                return count
            }
        }
        return nil
    }

    private static func integer(named name: String, in line: String) -> Int? {
        let marker = "\"\(name)\":"
        guard let markerRange = line.range(of: marker) else { return nil }
        let digits = line[markerRange.upperBound...].prefix(while: { $0.isNumber })
        return Int(digits)
    }
}

/// Parses only recent, known node messages. This deliberately avoids treating
/// an old line that remains in the log tail as current recovery evidence.
public enum ChainProgressLogParser {
    public static let observationWindow: TimeInterval = 3 * 60

    public static func parse(
        _ text: String,
        now: Date = Date(),
        window: TimeInterval = observationWindow
    ) -> ChainProgressEvidence? {
        var evidence = ChainProgressEvidence(observedAt: .distantPast)
        var matched = false

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = String(rawLine)
            guard let timestamp = timestamp(in: line) else { continue }
            let age = now.timeIntervalSince(timestamp)
            guard age >= -5, age <= window else { continue }
            var lineMatched = false

            if line.contains("archive poller connected") {
                evidence.archiveConnections += 1
                lineMatched = true
                matched = true
            }

            if line.contains("archive poller: gossip is carrying the head") {
                evidence.archiveRPCStandby += 1
                lineMatched = true
                matched = true
            }

            if line.contains("connect_mtls failed (full chain)") {
                evidence.archiveConnectionFailures += 1
                lineMatched = true
                matched = true
            }

            if line.contains("archive poller: not advancing"),
                let endpoint = integer(named: "endpoint_head", in: line),
                let local = integer(named: "local_frame", in: line)
            {
                evidence.highestArchiveFrame = max(evidence.highestArchiveFrame ?? 0, endpoint)
                if endpoint > local {
                    evidence.archiveAheadOfLocalHead += 1
                } else if endpoint == local {
                    evidence.archiveAtLocalHead += 1
                }
                lineMatched = true
                matched = true
            }

            if line.contains("all archive endpoints failed"),
                line.contains("zero shard sizes")
            {
                evidence.zeroShardSizeResponses += 1
                lineMatched = true
                matched = true
            }
            if line.contains("shard_info refresh: zero-valued result") {
                evidence.zeroShardSizeResponses += 1
                lineMatched = true
                matched = true
            }
            if line.contains("no reachable peer holds the finalized prover root") {
                evidence.finalizedRootUnavailable += 1
                lineMatched = true
                matched = true
            }
            if line.contains("peer vertex-adds root != expected") {
                evidence.vertexRootMismatches += 1
                lineMatched = true
                matched = true
            }
            if line.contains("archive anchor validation failed") {
                evidence.archiveAnchorRejections += 1
                lineMatched = true
                matched = true
            }

            if lineMatched {
                evidence.observedAt = max(evidence.observedAt, timestamp)
            }
        }

        return matched ? evidence : nil
    }

    public static func isArchiveRecoveryMessage(_ line: String) -> Bool {
        line.contains("archive poller: not advancing")
            || line.contains("archive poller connected")
            || (line.contains("all archive endpoints failed") && line.contains("zero shard sizes"))
            || line.contains("shard_info refresh: zero-valued result")
            || line.contains("shard_info refresh: endpoint failed, rotating")
            || line.contains("connect_mtls failed (full chain)")
            || line.contains("no reachable peer holds the finalized prover root")
            || line.contains("peer vertex-adds root != expected")
            || line.contains("archive anchor validation failed")
    }

    private static func timestamp(in line: String) -> Date? {
        guard let token = line.split(separator: "\t", maxSplits: 1).first else { return nil }
        return try? Date(String(token), strategy: .iso8601)
    }

    private static func integer(named name: String, in line: String) -> UInt64? {
        let marker = "\"\(name)\":"
        guard let markerRange = line.range(of: marker) else { return nil }
        let suffix = line[markerRange.upperBound...]
        let digits = suffix.prefix(while: { $0.isNumber })
        return UInt64(digits)
    }
}

public enum ChainProgressState: String, Codable, Sendable {
    /// Frames are moving or the observation baseline is not yet long enough.
    case advancing
    /// Progress is quiet, but there is not enough evidence to diagnose why.
    case observing
    /// Archives are reachable but their shared state is still converging.
    case archiveRecovery
    /// A reachable archive reports a newer frame than this node.
    case localLag
    /// The local node appears isolated or stuck after a conservative grace period.
    case localStall
}

public struct ChainProgressAssessment: Equatable, Sendable {
    public var state: ChainProgressState
    public var stagnantFor: TimeInterval?
    public var evidence: ChainProgressEvidence?

    public init(
        state: ChainProgressState,
        stagnantFor: TimeInterval? = nil,
        evidence: ChainProgressEvidence? = nil
    ) {
        self.state = state
        self.stagnantFor = stagnantFor
        self.evidence = evidence
    }

    public var suppressesLocalRepair: Bool { state == .archiveRecovery }
}

/// One policy shared by Dashboard, Diagnostics, milestones, and menu-bar UI.
/// Recovery needs two independent signal families: a healthy connected node,
/// plus archive/head evidence and archive-state convergence evidence.
public enum ChainProgressEvaluator {
    public static let quietObservationThreshold: TimeInterval = 2 * 60
    public static let recoveryClassificationThreshold: TimeInterval = 5 * 60
    public static let localRepairThreshold: TimeInterval = 20 * 60

    public static func evaluate(_ snapshot: NodeSnapshot, now: Date = Date()) -> ChainProgressAssessment {
        guard snapshot.isRunning, snapshot.frame > 0 else {
            return ChainProgressAssessment(state: .observing, evidence: snapshot.chainProgressEvidence)
        }

        let evidence = snapshot.chainProgressEvidence
        let evidenceIsFresh =
            evidence.map { now.timeIntervalSince($0.observedAt) <= ChainProgressLogParser.observationWindow } == true
        let hasArchiveSource =
            (snapshot.archiveEndpointCount ?? 0) > 0
            || snapshot.archivePeers > 0
            || (evidence?.archiveConnections ?? 0) > 0
        let transportIsHealthy =
            snapshot.peers >= 3
            && hasArchiveSource
            && snapshot.isLogFresh(at: now)

        if evidenceIsFresh, transportIsHealthy, let evidence {
            let archiveIsAhead =
                evidence.archiveAheadOfLocalHead > 0
                || (evidence.highestArchiveFrame.map { $0 > snapshot.frame } ?? false)
            if archiveIsAhead {
                let stagnantFor = snapshot.frameLastAdvancedAt.map { max(now.timeIntervalSince($0), 0) }
                return ChainProgressAssessment(state: .localLag, stagnantFor: stagnantFor, evidence: evidence)
            }

            let archiveAgreesWithHead = evidence.archiveAtLocalHead > 0
            let stateIsConverging = evidence.recoverySignalCount > 0
            let strongFreshEvidence =
                evidence.archiveAtLocalHead >= 2
                && evidence.recoverySignalCount >= 3
            let stagnantFor = snapshot.frameLastAdvancedAt.map { max(now.timeIntervalSince($0), 0) }
            let baselineConfirmsHold = stagnantFor.map { $0 >= recoveryClassificationThreshold } == true
            if archiveAgreesWithHead, stateIsConverging, strongFreshEvidence || baselineConfirmsHold {
                return ChainProgressAssessment(state: .archiveRecovery, stagnantFor: stagnantFor, evidence: evidence)
            }
        }

        guard let advancedAt = snapshot.frameLastAdvancedAt else {
            return ChainProgressAssessment(state: .observing, evidence: evidence)
        }

        let stagnantFor = max(now.timeIntervalSince(advancedAt), 0)
        guard stagnantFor >= quietObservationThreshold else {
            return ChainProgressAssessment(state: .advancing, stagnantFor: stagnantFor, evidence: evidence)
        }

        let state: ChainProgressState = stagnantFor >= localRepairThreshold ? .localStall : .observing
        return ChainProgressAssessment(state: state, stagnantFor: stagnantFor, evidence: evidence)
    }
}
