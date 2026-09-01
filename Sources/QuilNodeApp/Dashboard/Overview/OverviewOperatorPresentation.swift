import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

/// The deliberately small set of evidence that belongs on the landing page.
/// Detailed shard, identity, activity and diagnostic data remains in its
/// feature workspace; Overview only answers whether the node is participating,
/// connected, identified and receiving observable reward evidence.
struct OverviewOperatorPresentation: Equatable {
    struct Participation: Equatable {
        let activeAllocations: Int
        let runningWorkers: Int?
        let coverage: ShardCoverageState?

        var coverageLabel: String { coverage?.label ?? "Checking" }
    }

    struct Network: Equatable {
        let peers: Int
        let archiveSources: Int?
        let inboundObserved: Bool
    }

    struct Identity: Equatable {
        let seniority: Int64
    }

    struct Rewards: Equatable {
        let balance: String?
        let lastCreditFrame: UInt64?
    }

    let participation: Participation
    let network: Network
    let identity: Identity
    let rewards: Rewards
    let latestActivity: NodeActivityEvent?

    static func make(
        snapshot: NodeSnapshot,
        activitySamples: [NodeActivitySample]
    ) -> Self {
        let allocation = AllocationLatticePresentation.make(snapshot: snapshot)
        return Self(
            participation: Participation(
                activeAllocations: allocation.activeAllocations,
                runningWorkers: allocation.runningWorkers,
                coverage: allocation.coverageState
            ),
            network: Network(
                peers: snapshot.peers,
                archiveSources: snapshot.archiveEndpointCount,
                inboundObserved: (snapshot.inboundConnectionsEstablished ?? 0) > 0
            ),
            identity: Identity(seniority: snapshot.seniority),
            rewards: Rewards(
                balance: snapshot.quilBalance,
                lastCreditFrame: snapshot.lastRewardCreditFrame
            ),
            latestActivity: NodeActivityAnalyzer.events(from: activitySamples).first
        )
    }
}
