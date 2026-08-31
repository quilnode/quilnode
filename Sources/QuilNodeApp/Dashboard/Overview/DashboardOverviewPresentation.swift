import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

/// Read-only presentation values shared by the overview's component files.
/// Keeping these derivations together prevents individual views from subtly
/// disagreeing about frame, epoch, reward, or recovery state.
extension DashboardView {
    var provingPhaseDetail: String {
        nodeObservation.primaryDetail ?? participationEvidence.detail
    }

    var overviewEyebrow: String {
        nodeObservation.hasLiveTelemetry ? DashboardCopy.Overview.eyebrow : "LOCAL OBSERVATION"
    }

    var effectiveFrame: UInt64 {
        epochClock.frame
    }

    var epochClock: NodeEpochClock { monitor.snapshot.epochClock }

    var currentEpoch: UInt64 {
        epochClock.epoch
    }

    var epochProgress: Double {
        epochClock.progress
    }

    var framesUntilEpoch: UInt64 {
        epochClock.framesRemaining
    }

    var epochCompactETA: String {
        EpochEstimateFormatter.compact(snapshot: monitor.snapshot)
    }

    var chainProgress: ChainProgressAssessment {
        ChainProgressEvaluator.evaluate(monitor.snapshot)
    }

    var balanceDetail: String {
        DashboardCopy.balanceDetail(
            hasBalance: monitor.snapshot.quilBalance != nil,
            error: monitor.snapshot.balanceError,
            isRunning: monitor.snapshot.isRunning
        )
    }

    var rewardStatusTitle: String {
        participationEvidence.rewardTitle
    }

    var rewardSystemImage: String {
        participationEvidence.rewardSystemImage
    }

    var rewardTint: Color {
        switch participationEvidence.rewardState {
        case .networkWaiting: theme.colors.info
        case .creditObserved: theme.colors.success
        case .noCreditObserved: theme.colors.warning
        case .notEligible: theme.colors.secondaryText
        }
    }

    var participationEvidence: ParticipationEvidencePresentation {
        ParticipationEvidencePresentation.make(snapshot: monitor.snapshot)
    }

    var allocationLattice: AllocationLatticePresentation {
        AllocationLatticePresentation.make(snapshot: monitor.snapshot)
    }
}
