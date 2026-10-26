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
        let activeAllocations: Int?
        let joiningAllocations: Int?
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
        let seniorityIsObserved: Bool
    }

    struct Rewards: Equatable {
        let balance: String?
        let claimable: String?
        let hasModernWallet: Bool
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
        let allocationsObserved =
            snapshot.proverStatusUpdatedAt != nil
            || !snapshot.shardAllocations.isEmpty || snapshot.totalAllocations > 0
        return Self(
            participation: Participation(
                activeAllocations: allocationsObserved ? allocation.activeAllocations : nil,
                joiningAllocations: allocationsObserved ? allocation.joiningAllocations : nil,
                runningWorkers: allocation.runningWorkers,
                coverage: allocation.coverageState
            ),
            network: Network(
                peers: snapshot.peers,
                archiveSources: snapshot.archiveEndpointCount,
                inboundObserved: (snapshot.inboundConnectionsEstablished ?? 0) > 0
            ),
            identity: Identity(
                seniority: snapshot.seniority,
                seniorityIsObserved: snapshot.hasSeniorityObservation
            ),
            rewards: Rewards(
                balance: snapshot.quilBalance,
                claimable: snapshot.walletBalance?.rewards?.amount,
                hasModernWallet: snapshot.walletBalance?.isLegacyFormat == false,
                lastCreditFrame: snapshot.lastRewardCreditFrame
            ),
            latestActivity: NodeActivityAnalyzer.events(from: activitySamples).first
        )
    }
}
