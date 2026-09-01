import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

/// A compact projection of local worker evidence for the landing page.
///
/// The Overview deliberately keeps only enough detail to answer which local
/// workers are running and what allocation each one currently serves. The
/// complete roster, storage evidence and shard dossier remain in Network.
struct OverviewWorkerRosterPresentation: Equatable {
    enum AllocationState: Equatable {
        case active
        case joining
        case attention
        case awaitingAllocation
    }

    struct Worker: Equatable, Identifiable {
        let coreID: Int
        let filter: String?
        let availableStorage: String?
        let totalStorage: String?
        let allocationLabel: String
        let allocationState: AllocationState
        let coverage: ShardCoverageState?
        let activeProvers: Int?
        let ring: Int?

        var id: Int { coreID }
    }

    let workers: [Worker]
    let reportedRunningCount: Int?
    let isAwaitingEvidence: Bool

    static func make(snapshot: NodeSnapshot) -> Self {
        let observedWorkers = (snapshot.localWorkers ?? []).sorted { $0.coreID < $1.coreID }
        let sourceWorkers: [LocalWorkerObservation]

        if observedWorkers.isEmpty, let count = snapshot.localWorkerCount, count > 0 {
            sourceWorkers = (1...count).map {
                LocalWorkerObservation(
                    coreID: $0,
                    filter: "",
                    availableStorage: "",
                    totalStorage: ""
                )
            }
        } else {
            sourceWorkers = observedWorkers
        }

        let workers = sourceWorkers.map { worker in
            let allocation = allocation(for: worker, in: snapshot.shardAllocations)
            let status = allocation.map { AllocationStatus($0.status) }
            return Worker(
                coreID: worker.coreID,
                filter: nonEmpty(worker.filter) ?? allocation.flatMap { nonEmpty($0.filter) },
                availableStorage: nonEmpty(worker.availableStorage),
                totalStorage: nonEmpty(worker.totalStorage),
                allocationLabel: label(for: status),
                allocationState: state(for: status),
                coverage: allocation?.coverageState,
                activeProvers: allocation?.activeProvers,
                ring: allocation?.ring
            )
        }

        return Self(
            workers: workers,
            reportedRunningCount: snapshot.localWorkerCount ?? (workers.isEmpty ? nil : workers.count),
            isAwaitingEvidence: snapshot.isRunning
                && snapshot.localWorkers == nil
                && snapshot.localWorkerCount == nil
        )
    }

    func visibleWorkers(limit: Int) -> [Worker] {
        Array(workers.prefix(max(limit, 0)))
    }

    private static func allocation(
        for worker: LocalWorkerObservation,
        in allocations: [ShardAllocation]
    ) -> ShardAllocation? {
        if let filter = nonEmpty(worker.filter),
            let exactMatch = allocations.first(where: { $0.filter == filter })
        {
            return exactMatch
        }

        return allocations.first { allocation in
            workerID(from: allocation.worker) == worker.coreID
        }
    }

    private static func workerID(from value: String?) -> Int? {
        guard let value = nonEmpty(value) else { return nil }
        if let direct = Int(value) { return direct }

        let prefix = "worker "
        let normalized = value.lowercased()
        guard normalized.hasPrefix(prefix) else { return nil }
        return Int(normalized.dropFirst(prefix.count))
    }

    private static func label(for status: AllocationStatus?) -> String {
        switch status {
        case .active: "Active"
        case .joining: "Joining"
        case .paused: "Paused"
        case .leaving: "Leaving"
        case .expiredJoin: "Join expired"
        case .expiredLeave: "Leave expired"
        case .renewalMissed: "Renewal missed"
        case .rejected: "Rejected"
        case .kicked: "Kicked"
        case .historic: "Historic"
        case .unknown: "Unknown"
        case nil: "Awaiting assignment"
        }
    }

    private static func state(for status: AllocationStatus?) -> AllocationState {
        switch status {
        case .active: .active
        case .joining: .joining
        case nil: .awaitingAllocation
        default: .attention
        }
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
