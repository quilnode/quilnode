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

        switch AllocationStatus(allocation.status) {
        case .active:
            lifecycle = .active
            lifecycleLabel = "Active"
        case .joining:
            lifecycle = .joining
            lifecycleLabel = (allocation.confirmFrame ?? 0) > 0 ? "Confirmed · waiting" : "Joining"
        case .leaving:
            lifecycle = .leaving
            lifecycleLabel = "Leaving"
        case .expiredJoin:
            lifecycle = .attention
            lifecycleLabel = "Join expired"
        case .expiredLeave:
            lifecycle = (allocation.leaveConfirmFrame ?? 0) > 0 ? .leaving : .attention
            lifecycleLabel = (allocation.leaveConfirmFrame ?? 0) > 0 ? "Departed" : "Leave expired"
        case .renewalMissed:
            lifecycle = .attention
            lifecycleLabel = "Renewal missed"
        case .rejected, .kicked:
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
