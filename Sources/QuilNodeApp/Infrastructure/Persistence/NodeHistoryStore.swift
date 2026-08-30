import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

struct NodeHistoryPoint: Codable, Equatable, Identifiable, Sendable {
    var timestamp: Date
    var frame: UInt64
    var peers: Int
    var pendingJoins: Int
    var activeShards: Int
    var cpuPercent: Double
    var memoryMB: Double
    var isRunning: Bool
    /// Consensus seniority as observed by the local node. Optional fields keep
    /// history files written by earlier QuilNode versions decodable.
    var seniority: Int64?
    var seniorityObservedAt: Date?
    var totalAllocations: Int?
    var inboundConnections: UInt64?
    var framesReceived: UInt64?
    var routerDrops: UInt64?
    var lastRewardCreditFrame: UInt64?
    var version: String?
    var chainProgressState: ChainProgressState?

    var id: Date { timestamp }

    var activitySample: NodeActivitySample {
        NodeActivitySample(
            timestamp: timestamp,
            frame: frame,
            peers: peers,
            pendingJoins: pendingJoins,
            activeShards: activeShards,
            totalAllocations: totalAllocations ?? max(pendingJoins + activeShards, 0),
            isRunning: isRunning,
            seniority: seniority,
            inboundConnections: inboundConnections,
            framesReceived: framesReceived,
            routerDrops: routerDrops,
            lastRewardCreditFrame: lastRewardCreditFrame,
            version: version,
            chainProgressState: chainProgressState
        )
    }
}

@MainActor
final class NodeHistoryStore: ObservableObject {
    @Published private(set) var points: [NodeHistoryPoint] = []

    private let sampleInterval: TimeInterval = 30
    private let retentionInterval: TimeInterval = 7 * 24 * 60 * 60
    private let fileURL: URL
    private var lastPersistedAt: Date?

    init() {
        let base =
            FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? FileManager.default.homeDirectoryForCurrentUser
        let directory = base.appendingPathComponent("QuilNode", isDirectory: true)
        fileURL = directory.appendingPathComponent("node-history.json")
        load()
    }

    func record(_ snapshot: NodeSnapshot) {
        let now = snapshot.collectedAt
        let previous = points.last
        let stateChanged =
            previous.map {
                $0.isRunning != snapshot.isRunning
                    || $0.pendingJoins != snapshot.pendingJoins
                    || $0.activeShards != snapshot.activeShards
                    || $0.totalAllocations != snapshot.totalAllocations
                    || $0.inboundConnections != snapshot.inboundConnectionsEstablished
                    || $0.lastRewardCreditFrame != snapshot.lastRewardCreditFrame
                    || $0.version != snapshot.version
                    || $0.chainProgressState != ChainProgressEvaluator.evaluate(snapshot, now: now).state
                    || $0.seniority != positiveSeniority(in: snapshot)
                    || $0.seniorityObservedAt != snapshot.seniorityUpdatedAt
            } ?? true
        guard
            stateChanged
                || previous.map({ now.timeIntervalSince($0.timestamp) >= sampleInterval }) != false
        else { return }

        points.append(
            NodeHistoryPoint(
                timestamp: now,
                frame: snapshot.frame,
                peers: snapshot.peers,
                pendingJoins: snapshot.pendingJoins,
                activeShards: snapshot.activeShards,
                cpuPercent: snapshot.cpuPercent ?? 0,
                memoryMB: snapshot.memoryMB ?? 0,
                isRunning: snapshot.isRunning,
                seniority: positiveSeniority(in: snapshot),
                seniorityObservedAt: snapshot.seniorityUpdatedAt,
                totalAllocations: snapshot.totalAllocations,
                inboundConnections: snapshot.inboundConnectionsEstablished,
                framesReceived: snapshot.framesReceived,
                routerDrops: snapshot.routerDrops,
                lastRewardCreditFrame: snapshot.lastRewardCreditFrame,
                version: snapshot.version,
                chainProgressState: ChainProgressEvaluator.evaluate(snapshot, now: now).state
            )
        )
        points.removeAll { now.timeIntervalSince($0.timestamp) > retentionInterval }

        if stateChanged || lastPersistedAt.map({ now.timeIntervalSince($0) >= 60 }) != false {
            persist()
            lastPersistedAt = now
        }
    }

    func points(since interval: TimeInterval) -> [NodeHistoryPoint] {
        let cutoff = Date().addingTimeInterval(-interval)
        return points.filter { $0.timestamp >= cutoff }
    }

    func activitySamples(since interval: TimeInterval) -> [NodeActivitySample] {
        points(since: interval).map(\.activitySample)
    }

    func seniorityTrend(for snapshot: NodeSnapshot, now: Date = Date()) -> SeniorityTrend {
        let samples = points.compactMap { point -> SenioritySample? in
            guard let value = point.seniority,
                let observedAt = point.seniorityObservedAt
            else { return nil }
            return SenioritySample(value: value, observedAt: observedAt)
        }
        return SeniorityTrend.evaluate(
            currentValue: snapshot.seniority,
            previousValue: snapshot.previousSeniority,
            currentObservedAt: snapshot.seniorityUpdatedAt,
            samples: samples,
            now: now
        )
    }

    private func positiveSeniority(in snapshot: NodeSnapshot) -> Int64? {
        snapshot.seniority > 0 ? snapshot.seniority : nil
    }

    private func load() {
        guard let data = try? BoundedLocalData.read(from: fileURL, maximumBytes: 8 * 1_024 * 1_024),
            let decoded = try? JSONDecoder.historyDecoder.decode(
                [NodeHistoryPoint].self,
                from: data
            )
        else { return }
        let cutoff = Date().addingTimeInterval(-retentionInterval)
        points = decoded.filter { $0.timestamp >= cutoff }
    }

    private func persist() {
        do {
            try PrivateLocalFileSystem.ensureDirectory(at: fileURL.deletingLastPathComponent())
            let data = try JSONEncoder.historyEncoder.encode(points)
            try PrivateLocalFileSystem.write(data, atomicallyTo: fileURL)
        } catch {
            // History is best-effort and must never interfere with node monitoring.
        }
    }
}

private extension JSONEncoder {
    static var historyEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var historyDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
