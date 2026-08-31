import Foundation

extension NodeDiagnosticEvaluator {
    static func allocationEpochCheck(_ context: NodeDiagnosticContext) -> NodeDiagnosticCheck? {
        let snapshot = context.snapshot
        guard !snapshot.shardAllocations.isEmpty else { return nil }
        func result(
            _ state: NodeDiagnosticState, _ summary: String, _ evidence: String,
            repair: NodeDiagnosticRepair? = nil
        ) -> NodeDiagnosticCheck {
            check(
                id: "allocation-epochs", category: .progress, state: state,
                title: "Allocation epoch readiness", summary: summary, evidence: evidence,
                observedAt: snapshot.proverStatusUpdatedAt, repair: repair
            )
        }
        guard context.initialRefreshComplete, snapshot.hasFreshProverStatus(at: context.now) else {
            return result(
                .checking, "Waiting for fresh allocation evidence.",
                "An old allocation read cannot establish a missed confirmation or renewal.", repair: .refreshEvidence
            )
        }
        let timings = snapshot.shardAllocations.map {
            AllocationEpochTiming.evaluate($0, clock: snapshot.epochClock)
        }
        if timings.contains(.renewalMissed) || timings.contains(.windowMissed) {
            return result(
                .advisory, "The local registry reports a missed renewal or confirmation.",
                "The node normally manages confirmations and renewal automatically. Refresh evidence and inspect local lifecycle messages. A missed epoch alone does not justify restarting or wiping stores.",
                repair: .refreshEvidence
            )
        }
        if timings.contains(.awaitingRegistry) {
            return result(
                .checking, "Frame progress has crossed an allocation boundary.",
                "Waiting for the next registry read before reporting activation, departure or renewal failure.",
                repair: .refreshEvidence
            )
        }
        if timings.contains(where: {
            switch $0 {
            case .activation, .departure, .confirmationOpens, .confirmationCloses: true
            default: false
            }
        }) {
            return result(
                .waiting, "Allocations are following the epoch schedule.",
                "A confirmed join stays Joining until the following epoch. Active data allocations renew for the next epoch. Keep the node online; frame progress, not wall-clock time, controls these transitions."
            )
        }
        if snapshot.shardAllocations.allSatisfy({ AllocationStatus($0.status) == .active }) {
            return result(
                .passed, "The local registry reports active allocations.",
                "Data-shard registration and actual reward credits are separate evidence. Global allocations have no data-shard renewal obligation."
            )
        }
        return result(
            .checking, "No pending epoch deadline can be established.",
            "Paused, departed, historic or unrecognized allocation states are not counted as successful activation.",
            repair: .refreshEvidence
        )
    }
}
