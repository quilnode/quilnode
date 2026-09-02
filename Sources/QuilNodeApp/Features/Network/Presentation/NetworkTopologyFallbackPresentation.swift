import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

/// Keeps fallback topology policy separate from the observatory's layout and
/// filtering logic. Persisted rows remain public-only; local relationships are
/// reattached from the current in-memory status observation.
enum NetworkTopologyFallbackPresentation {
    static func attachLocalAllocations(
        to shards: [NetworkShardObservation],
        allocations: [ShardAllocation]
    ) -> [NetworkShardObservation] {
        let byFilter = Dictionary(
            allocations.map { ($0.filter.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return shards.map { shard in
            guard let allocation = byFilter[shard.filter.lowercased()] else { return shard }
            var enriched = shard
            enriched.isAllocated = true
            enriched.worker = allocation.worker
            return enriched
        }
    }

    static func issue(for snapshot: NodeSnapshot) -> String? {
        guard snapshot.networkShardError != nil else { return nil }
        if let evidence = snapshot.chainProgressEvidence,
            evidence.archiveConnectionFailures > 0 || evidence.finalizedRootUnavailable > 0
        {
            return
                "Archive-backed shard metadata is temporarily unavailable. The node and QuilNode will retry automatically."
        }
        return snapshot.networkShardError
    }
}
