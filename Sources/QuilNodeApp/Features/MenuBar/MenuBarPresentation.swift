import Foundation

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

/// Pure presentation logic for the menu-bar surface.
///
/// Keeping protocol interpretation out of SwiftUI makes the compact panel
/// easier to review, test, and evolve without duplicating dashboard copy.
struct MenuBarPresentation {
    let snapshot: NodeSnapshot
    let phase: NodeObservationPhase

    var hasLiveTelemetry: Bool { phase.hasLiveTelemetry }

    private var chainProgress: ChainProgressAssessment {
        ChainProgressEvaluator.evaluate(snapshot)
    }

    var effectiveFrame: UInt64 {
        max(snapshot.frame, snapshot.lastReceivedFrame)
    }

    var epoch: UInt64 {
        snapshot.epoch > 0
            ? snapshot.epoch
            : effectiveFrame / max(snapshot.epochLength, 1)
    }

    var epochProgress: Double {
        let length = max(snapshot.epochLength, 1)
        return min(max(Double(effectiveFrame % length) / Double(length), 0), 1)
    }

    var framesUntilEpoch: UInt64 {
        let length = max(snapshot.epochLength, 1)
        if snapshot.nextEpochFrame > effectiveFrame {
            return snapshot.nextEpochFrame - effectiveFrame
        }
        let remainder = effectiveFrame % length
        return remainder == 0 ? length : length - remainder
    }

    var epochETA: String {
        if chainProgress.state == .archiveRecovery {
            return "Waiting on archives"
        }
        return EpochEstimateFormatter.compact(
            framesRemaining: framesUntilEpoch,
            framesPerMinute: snapshot.framesPerMinute
        )
    }

    var participationTitle: String {
        if phase == .checkingProcess { return "Checking Local Node" }
        if phase == .loadingTelemetry {
            return snapshot.isRunning ? "Node Detected" : "Node Offline"
        }
        guard snapshot.isRunning else { return "Node Offline" }
        if chainProgress.state == .archiveRecovery { return "Prover Waiting" }
        if snapshot.activeShards > 0 { return "Prover Active" }
        if snapshot.pendingJoins > 0 { return "Joining Shards" }
        if snapshot.totalAllocations > 0 { return "Awaiting Activation" }
        return "Connected"
    }

    var participationDetail: String {
        if phase == .checkingProcess {
            return "Reading the managed launchd service; no node state has been assumed."
        }
        if phase == .loadingTelemetry, snapshot.isRunning {
            return "The process is running. Frames, peers, identity, and allocations are loading locally."
        }
        if phase == .loadingTelemetry {
            return "The managed service check confirmed that the node is stopped."
        }
        guard snapshot.isRunning else {
            return "The local node service is stopped."
        }
        if chainProgress.state == .archiveRecovery {
            return "Allocations remain active; archive state is converging. No restart is recommended."
        }
        if snapshot.activeShards > 0 {
            return snapshot.lastRewardCreditFrame == nil
                ? "Serving assigned work; no reward credit has been observed locally yet."
                : "Serving assigned work with a locally observed reward credit."
        }
        if snapshot.pendingJoins > 0 {
            return "Registered and waiting for shard activation."
        }
        if snapshot.totalAllocations > 0 {
            return "Allocations are recognized but not active yet."
        }
        return "Online and synchronized; waiting for an allocation."
    }

    var participationSystemImage: String {
        if phase == .checkingProcess { return "ellipsis.circle.fill" }
        if phase == .loadingTelemetry, snapshot.isRunning { return "checkmark.circle.fill" }
        if !snapshot.isRunning { return "power" }
        if chainProgress.state == .archiveRecovery { return "hourglass" }
        if snapshot.activeShards > 0 { return "bolt.shield.fill" }
        if snapshot.pendingJoins > 0 { return "hourglass" }
        return "network"
    }

    var participationCount: Int? {
        if snapshot.activeShards > 0 { return snapshot.activeShards }
        if snapshot.pendingJoins > 0 { return snapshot.pendingJoins }
        if snapshot.totalAllocations > 0 { return snapshot.totalAllocations }
        return nil
    }

    var participationCountSuffix: String {
        if snapshot.activeShards > 0 { return " active" }
        if snapshot.pendingJoins > 0 { return " joining" }
        return " waiting"
    }

    var rewardTitle: String {
        if chainProgress.state == .archiveRecovery { return "Network waiting" }
        if snapshot.lastRewardCreditFrame != nil { return "Credit observed" }
        if snapshot.activeShards > 0 { return "Rewards pending" }
        return "Not eligible yet"
    }

    var rewardDetail: String {
        if chainProgress.state == .archiveRecovery {
            return "Reward-bearing frames are waiting for shared archive state to converge."
        }
        if let frame = snapshot.lastRewardCreditFrame {
            return "Reward credit observed at frame \(frame.grouped)."
        }
        if snapshot.activeShards > 0 {
            return "Active work establishes eligibility, not guaranteed payment."
        }
        return "Eligibility begins after a shard allocation becomes active."
    }

    var reachabilityTitle: String {
        switch snapshot.reachable {
        case true: "Inbound reachable"
        case false: "Outbound only"
        case nil: "Reachability unknown"
        }
    }

    var memoryText: String {
        snapshot.memoryMB.map { String(format: "%.1f GB", $0 / 1024) } ?? "—"
    }

    var quilBalanceText: String {
        guard var balance = snapshot.quilBalance else { return "—" }
        guard balance.contains(".") else { return balance }
        while balance.last == "0" { balance.removeLast() }
        if balance.last == "." { balance.removeLast() }
        return balance.isEmpty ? "0" : balance
    }

    var cpuText: String {
        CPUUsagePresentation(snapshot: snapshot).compactValueText
    }

    var versionText: String {
        snapshot.version ?? "Local build"
    }
}
