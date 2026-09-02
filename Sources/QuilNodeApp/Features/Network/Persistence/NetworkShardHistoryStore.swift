import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif
#if canImport(QuilNodeShared)
    import QuilNodeShared
#endif

enum NetworkShardChangeField: String, Codable, CaseIterable, Equatable, Sendable {
    case appeared
    case activeProvers
    case ring
    case shardSize
    case dataShards
    case estimatedReward

    var label: String {
        switch self {
        case .appeared: "Newly observed"
        case .activeProvers: "Prover count"
        case .ring: "Ring"
        case .shardSize: "Storage"
        case .dataShards: "Data shards"
        case .estimatedReward: "Reward estimate"
        }
    }
}

struct NetworkShardChangeRecord: Codable, Equatable, Identifiable, Sendable {
    let filter: String
    let observedAt: Date
    let fields: [NetworkShardChangeField]

    var id: String { filter }

    var summary: String {
        guard fields.count != 1 else { return fields[0].label }
        return "\(fields.count) metrics changed"
    }
}

/// A privacy-safe last-known-good shard table. Local allocation relationships
/// are intentionally reattached from live memory by presentation code and are
/// never written to this cache.
struct CachedNetworkShardTopology: Equatable, Sendable {
    let shards: [NetworkShardObservation]
    let observedAt: Date
}

/// Retains only public shard-table fingerprints from the local qclient. The
/// store deliberately excludes local allocation links, worker identifiers and
/// every node or wallet identity so its history remains safe in Privacy Mode.
@MainActor
final class NetworkShardHistoryStore: ObservableObject {
    @Published private(set) var recentChanges: [String: NetworkShardChangeRecord] = [:]
    @Published private(set) var hasBaseline = false

    private static let retentionInterval: TimeInterval = 24 * 60 * 60
    private static let freshnessCheckpointInterval: TimeInterval = 60 * 60
    private static let maximumShardCount = 512
    private static let maximumChangeCount = 256
    private static let maximumFileBytes = 512 * 1_024

    private let fileURL: URL?
    private let now: () -> Date
    private var baseline: [String: NetworkShardFingerprint] = [:]
    private var lastObservedAt: Date?
    private var lastPersistedObservationAt: Date?

    init(fileURL: URL? = NetworkShardHistoryStore.defaultFileURL, now: @escaping () -> Date = Date.init) {
        self.fileURL = fileURL
        self.now = now
        load()
    }

    var cachedTopology: CachedNetworkShardTopology? {
        guard let lastObservedAt, !baseline.isEmpty else { return nil }
        let shards =
            baseline
            .map { filter, fingerprint in fingerprint.observation(filter: filter) }
            .sorted { $0.filter < $1.filter }
        return CachedNetworkShardTopology(shards: shards, observedAt: lastObservedAt)
    }

    func observe(_ shards: [NetworkShardObservation], observedAt: Date?) {
        guard !shards.isEmpty, let observedAt,
            lastObservedAt.map({ observedAt > $0 }) != false
        else { return }

        let current = Self.fingerprints(for: shards)
        guard !current.isEmpty else { return }

        if baseline.isEmpty {
            baseline = current
            lastObservedAt = observedAt
            hasBaseline = true
            persist()
            lastPersistedObservationAt = observedAt
            return
        }

        var detectedChanges: [String: NetworkShardChangeRecord] = [:]
        for (filter, fingerprint) in current {
            let fields = Self.changedFields(from: baseline[filter], to: fingerprint)
            guard !fields.isEmpty else { continue }
            detectedChanges[filter] = NetworkShardChangeRecord(
                filter: filter,
                observedAt: observedAt,
                fields: fields
            )
        }

        let baselineChanged = baseline != current
        baseline = current
        lastObservedAt = observedAt
        recentChanges.merge(detectedChanges) { _, newest in newest }
        prune(now: observedAt)

        // Checkpoint an unchanged table at most once per hour. This gives the
        // next launch an honest last-seen time without causing disk churn on
        // the one-minute live observation cadence.
        let checkpointIsDue =
            lastPersistedObservationAt.map {
                observedAt.timeIntervalSince($0) >= Self.freshnessCheckpointInterval
            } ?? true
        if baselineChanged || checkpointIsDue {
            persist()
            lastPersistedObservationAt = observedAt
        }
    }

    func changes(at date: Date? = nil) -> [String: NetworkShardChangeRecord] {
        let cutoff = (date ?? now()).addingTimeInterval(-Self.retentionInterval)
        return recentChanges.filter { $0.value.observedAt >= cutoff }
    }

    private func load() {
        guard let fileURL,
            let data = try? BoundedLocalData.read(from: fileURL, maximumBytes: Self.maximumFileBytes),
            let state = try? JSONDecoder.networkHistoryDecoder.decode(NetworkShardHistoryState.self, from: data)
        else { return }

        baseline = Dictionary(
            uniqueKeysWithValues: state.baseline
                .filter { Self.isValidFilter($0.key) }
                .sorted { $0.key < $1.key }
                .prefix(Self.maximumShardCount)
                .map { ($0.key, $0.value) }
        )
        lastObservedAt = state.lastObservedAt
        lastPersistedObservationAt = state.lastObservedAt
        recentChanges = Dictionary(
            uniqueKeysWithValues: state.recentChanges
                .filter { Self.isValidFilter($0.filter) }
                .sorted { $0.observedAt > $1.observedAt }
                .prefix(Self.maximumChangeCount)
                .map { ($0.filter, $0) }
        )
        hasBaseline = !baseline.isEmpty
        prune(now: now())
    }

    private func persist() {
        guard let fileURL else { return }
        do {
            try PrivateLocalFileSystem.ensureDirectory(at: fileURL.deletingLastPathComponent())
            let state = NetworkShardHistoryState(
                baseline: baseline,
                recentChanges: recentChanges.values.sorted { $0.observedAt > $1.observedAt },
                lastObservedAt: lastObservedAt
            )
            try PrivateLocalFileSystem.write(
                try JSONEncoder.networkHistoryEncoder.encode(state),
                atomicallyTo: fileURL
            )
        } catch {
            // Change history is best-effort and must never affect node monitoring.
        }
    }

    private func prune(now: Date) {
        let cutoff = now.addingTimeInterval(-Self.retentionInterval)
        let retained = recentChanges.values
            .filter { $0.observedAt >= cutoff }
            .sorted { $0.observedAt > $1.observedAt }
            .prefix(Self.maximumChangeCount)
        recentChanges = Dictionary(uniqueKeysWithValues: retained.map { ($0.filter, $0) })
    }

    private static func fingerprints(
        for shards: [NetworkShardObservation]
    ) -> [String: NetworkShardFingerprint] {
        let values =
            shards
            .filter { isValidFilter($0.filter) }
            .prefix(maximumShardCount)
            .map { shard in
                (
                    shard.filter,
                    NetworkShardFingerprint(
                        shardSize: shard.shardSize,
                        dataShards: shard.dataShards,
                        activeProvers: shard.activeProvers,
                        ring: shard.ring,
                        estimatedRewardPerFrame: shard.estimatedRewardPerFrame
                    )
                )
            }
        return Dictionary(values, uniquingKeysWith: { _, newest in newest })
    }

    private static func changedFields(
        from previous: NetworkShardFingerprint?,
        to current: NetworkShardFingerprint
    ) -> [NetworkShardChangeField] {
        guard let previous else { return [.appeared] }
        return NetworkShardChangeField.allCases.filter { field in
            switch field {
            case .appeared: false
            case .activeProvers: previous.activeProvers != current.activeProvers
            case .ring: previous.ring != current.ring
            case .shardSize: previous.shardSize != current.shardSize
            case .dataShards: previous.dataShards != current.dataShards
            case .estimatedReward:
                previous.estimatedRewardPerFrame != current.estimatedRewardPerFrame
            }
        }
    }

    private static func isValidFilter(_ filter: String) -> Bool {
        !filter.isEmpty && filter.utf8.count <= 512
    }

    private static var defaultFileURL: URL {
        let base =
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return
            base
            .appendingPathComponent("QuilNode", isDirectory: true)
            .appendingPathComponent("network-shard-history.json")
    }
}

private struct NetworkShardFingerprint: Codable, Equatable, Sendable {
    let shardSize: String
    let dataShards: Int
    let activeProvers: Int
    let ring: Int
    let estimatedRewardPerFrame: String

    func observation(filter: String) -> NetworkShardObservation {
        NetworkShardObservation(
            filter: filter,
            shardSize: shardSize,
            dataShards: dataShards,
            activeProvers: activeProvers,
            ring: ring,
            estimatedRewardPerFrame: estimatedRewardPerFrame,
            isAllocated: false
        )
    }
}

private struct NetworkShardHistoryState: Codable, Equatable, Sendable {
    let baseline: [String: NetworkShardFingerprint]
    let recentChanges: [NetworkShardChangeRecord]
    let lastObservedAt: Date?
}

private extension JSONEncoder {
    static var networkHistoryEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var networkHistoryDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
