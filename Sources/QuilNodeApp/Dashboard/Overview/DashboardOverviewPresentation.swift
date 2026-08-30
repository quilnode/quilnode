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
        max(monitor.snapshot.frame, monitor.snapshot.lastReceivedFrame)
    }

    var currentEpoch: UInt64 {
        if monitor.snapshot.epoch > 0 { return monitor.snapshot.epoch }
        return effectiveFrame / max(monitor.snapshot.epochLength, 1)
    }

    var epochProgress: Double {
        let length = max(monitor.snapshot.epochLength, 1)
        return min(max(Double(effectiveFrame % length) / Double(length), 0), 1)
    }

    var framesUntilEpoch: UInt64 {
        let length = max(monitor.snapshot.epochLength, 1)
        if monitor.snapshot.nextEpochFrame > effectiveFrame {
            return monitor.snapshot.nextEpochFrame - effectiveFrame
        }
        let remainder = effectiveFrame % length
        return remainder == 0 ? length : length - remainder
    }

    var epochCompactETA: String {
        if chainProgress.state == .archiveRecovery { return "Waiting on archives" }
        return EpochEstimateFormatter.compact(
            framesRemaining: framesUntilEpoch,
            framesPerMinute: monitor.snapshot.framesPerMinute
        )
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
