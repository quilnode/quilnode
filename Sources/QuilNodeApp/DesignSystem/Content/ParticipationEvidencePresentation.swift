import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

/// Conservative operator copy derived only from evidence the local node emits.
/// An active allocation establishes enrollment; it does not prove continuous
/// work, a successful proof submission, or a future reward.
struct ParticipationEvidencePresentation {
    enum State: Equatable {
        case offline
        case networkRecovery
        case activeAllocations
        case joining
        case allocated
        case awaitingAllocation
    }

    enum RewardState: Equatable {
        case networkWaiting
        case creditObserved
        case noCreditObserved
        case notEligible
    }

    let state: State
    let title: String
    let detail: String
    let summary: String
    let systemImage: String
    let rewardState: RewardState
    let rewardTitle: String
    let rewardDetail: String
    let rewardSummary: String
    let rewardSystemImage: String

    static func make(snapshot: NodeSnapshot) -> ParticipationEvidencePresentation {
        let chainProgress = ChainProgressEvaluator.evaluate(snapshot)
        let reward = rewardPresentation(snapshot: snapshot, chainProgress: chainProgress)

        if !snapshot.isRunning {
            return presentation(
                state: .offline,
                title: "Node offline",
                detail: "Start the node to resume synchronization and participation.",
                summary: "Managed service is stopped",
                systemImage: "power",
                reward: reward
            )
        }

        if chainProgress.state == .archiveRecovery {
            return presentation(
                state: .networkRecovery,
                title: "Allocations waiting",
                detail:
                    "Registry allocations remain active while shared archive state converges. Keep the node online.",
                summary: "Allocated; waiting for archive recovery",
                systemImage: "hourglass",
                reward: reward
            )
        }

        if snapshot.activeShards > 0 {
            return presentation(
                state: .activeAllocations,
                title: "Allocations active",
                detail:
                    "The consensus registry reports active shard allocations. This confirms enrollment, not continuous proof production.",
                summary: "Active registry allocations",
                systemImage: "checkmark.seal.fill",
                reward: reward
            )
        }

        if snapshot.pendingJoins > 0 {
            return presentation(
                state: .joining,
                title: "Allocations joining",
                detail: "The registry reports pending shard joins, but no active allocation yet.",
                summary: "Waiting for shard activation",
                systemImage: "arrow.triangle.2.circlepath",
                reward: reward
            )
        }

        if snapshot.totalAllocations > 0 {
            return presentation(
                state: .allocated,
                title: "Allocations waiting",
                detail: "Registry allocations are present, but none are active yet.",
                summary: "Allocations recognized; activation pending",
                systemImage: "clock.badge.checkmark",
                reward: reward
            )
        }

        return presentation(
            state: .awaitingAllocation,
            title: "Awaiting allocation",
            detail: "The node is online, but the registry reports no active shard allocation.",
            summary: "Connected; waiting for an allocation",
            systemImage: "hourglass",
            reward: reward
        )
    }

    private static func rewardPresentation(
        snapshot: NodeSnapshot,
        chainProgress: ChainProgressAssessment
    ) -> RewardPresentation {
        if chainProgress.state == .archiveRecovery {
            return RewardPresentation(
                state: .networkWaiting,
                title: "Network waiting",
                detail: "No new reward-bearing frame can be credited while shared archive state is converging.",
                summary: "Network recovery is holding reward-bearing frames",
                systemImage: "hourglass"
            )
        }
        if let frame = snapshot.lastRewardCreditFrame {
            return RewardPresentation(
                state: .creditObserved,
                title: "Credit observed",
                detail: "The local node recorded a reward credit at frame \(frame.grouped).",
                summary: "Credit observed at frame \(frame.grouped)",
                systemImage: "banknote.fill"
            )
        }
        if snapshot.activeShards > 0 {
            return RewardPresentation(
                state: .noCreditObserved,
                title: "No credit observed",
                detail:
                    "No reward credit is present in the local node log. Active allocations show eligibility, not guaranteed payment.",
                summary: "No local reward credit observed",
                systemImage: "clock.badge"
            )
        }
        return RewardPresentation(
            state: .notEligible,
            title: "Not eligible yet",
            detail: "Reward eligibility begins after a shard allocation becomes active.",
            summary: "Reward eligibility begins after activation",
            systemImage: "clock"
        )
    }

    private static func presentation(
        state: State,
        title: String,
        detail: String,
        summary: String,
        systemImage: String,
        reward: RewardPresentation
    ) -> ParticipationEvidencePresentation {
        ParticipationEvidencePresentation(
            state: state,
            title: title,
            detail: detail,
            summary: summary,
            systemImage: systemImage,
            rewardState: reward.state,
            rewardTitle: reward.title,
            rewardDetail: reward.detail,
            rewardSummary: reward.summary,
            rewardSystemImage: reward.systemImage
        )
    }

    private struct RewardPresentation {
        let state: RewardState
        let title: String
        let detail: String
        let summary: String
        let systemImage: String
    }
}
