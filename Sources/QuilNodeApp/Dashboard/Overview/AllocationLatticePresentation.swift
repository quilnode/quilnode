import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

/// Keeps the overview's three independent allocation dimensions explicit:
/// local worker runtime, allocation lifecycle, and network shard coverage.
/// They are intentionally not collapsed into a single "healthy" state.
struct AllocationLatticePresentation: Equatable {
    let runningWorkers: Int?
    let activeAllocations: Int
    let joiningAllocations: Int
    let totalAllocations: Int
    let coverageState: ShardCoverageState?

    static func make(snapshot: NodeSnapshot) -> Self {
        Self(
            runningWorkers: snapshot.localWorkerCount.flatMap { $0 > 0 ? $0 : nil },
            activeAllocations: snapshot.activeAllocations,
            joiningAllocations: snapshot.joiningAllocations,
            totalAllocations: snapshot.totalAllocations,
            coverageState: aggregateCoverage(snapshot.shardAllocations)
        )
    }

    var hasMixedLifecycle: Bool {
        activeAllocations > 0 && joiningAllocations > 0
    }

    private static func aggregateCoverage(
        _ allocations: [ShardAllocation]
    ) -> ShardCoverageState? {
        let states = allocations.compactMap(\.coverageState)
        if states.contains(.unassigned) { return .unassigned }
        if states.contains(.atRisk) { return .atRisk }
        if states.contains(.belowTarget) { return .belowTarget }
        if states.contains(.healthy) { return .healthy }
        return nil
    }
}

enum AllocationLifecycleKind: Equatable {
    case active
    case joining
    case leaving
    case attention
    case unknown
}

struct AllocationCellPresentation: Equatable {
    let lifecycle: AllocationLifecycleKind
    let lifecycleLabel: String
    let coverageLabel: String?

    init(allocation: ShardAllocation) {
        let normalized = allocation.status
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch normalized {
        case "active":
            lifecycle = .active
            lifecycleLabel = "Active"
        case "joining":
            lifecycle = .joining
            lifecycleLabel = "Joining"
        case "leaving":
            lifecycle = .leaving
            lifecycleLabel = "Leaving"
        case "rejected", "kicked", "expired", "expired_epoch", "expired_joining", "expired_leaving":
            lifecycle = .attention
            lifecycleLabel = normalized.replacingOccurrences(of: "_", with: " ").capitalized
        default:
            lifecycle = .unknown
            lifecycleLabel =
                normalized.isEmpty
                ? "Unknown"
                : normalized.replacingOccurrences(of: "_", with: " ").capitalized
        }

        coverageLabel = allocation.coverageState?.label
    }
}
