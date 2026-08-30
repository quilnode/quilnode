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

    /// Short copy for the menu-bar hero. The longer diagnostic explanation
    /// remains available through `participationDetail` and the Activity view.
    var participationSummary: String {
        if phase == .checkingProcess { return "Reading the managed service" }
        if phase == .loadingTelemetry {
            return snapshot.isRunning ? "Process found; loading local telemetry" : "Managed service is stopped"
        }
        guard snapshot.isRunning else { return "Managed service is stopped" }
        if chainProgress.state == .archiveRecovery { return "Allocated; waiting for archive recovery" }
        if snapshot.activeShards > 0 { return "Participating and syncing" }
        if snapshot.pendingJoins > 0 { return "Registered; waiting for shard activation" }
        if snapshot.totalAllocations > 0 { return "Allocations recognized; activation pending" }
        return "Connected; waiting for an allocation"
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

    var rewardSummary: String {
        if chainProgress.state == .archiveRecovery {
            return "Network recovery is holding reward-bearing frames"
        }
        if let frame = snapshot.lastRewardCreditFrame {
            return "Credit observed at frame \(frame.grouped)"
        }
        if snapshot.activeShards > 0 {
            return "Rewards pending — proving does not guarantee payment"
        }
        return "Reward eligibility begins after activation"
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

    var memoryFraction: Double {
        guard let memory = snapshot.memoryMB else { return 0 }
        let totalMB = Double(ProcessInfo.processInfo.physicalMemory) / 1_048_576
        guard totalMB > 0 else { return 0 }
        return min(max(memory / totalMB, 0), 1)
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

    var cpuFraction: Double {
        min(max((snapshot.cpuPercent ?? 0) / 100, 0), 1)
    }

    var seniorityText: String {
        guard hasLiveTelemetry, snapshot.seniority > 0 else { return "—" }
        return snapshot.seniority.formatted(.number.grouping(.automatic))
    }

    var epochProgressText: String {
        "\(Int((epochProgress * 100).rounded()))%"
    }

    var headerStatus: String {
        switch phase {
        case .checkingProcess: "Checking this Mac"
        case .loadingTelemetry: snapshot.isRunning ? "Live on this Mac" : "Stopped on this Mac"
        case .ready: snapshot.isRunning ? "Live on this Mac" : "Stopped on this Mac"
        }
    }

    func freshnessText(at now: Date) -> String {
        guard hasLiveTelemetry else { return "Updating" }
        let seconds = max(Int(now.timeIntervalSince(snapshot.collectedAt)), 0)
        if seconds < 5 { return "Updated now" }
        if seconds < 60 { return "Updated \(seconds)s ago" }
        if seconds < 3_600 { return "Updated \(seconds / 60)m ago" }
        return "Updated \(seconds / 3_600)h ago"
    }

    var versionText: String {
        snapshot.version ?? "Local build"
    }
}

/// A compact, time-bound milestone surfaced only when it is near enough to
/// affect current operation or when verified source evidence requires action.
/// Ordinary future milestones stay in Activity instead of permanently taking
/// space in the menu-bar panel.
struct MenuBarMilestonePresentation: Equatable {
    private typealias Candidate = (
        milestone: ProtocolMilestone,
        state: ProtocolMilestonePresentationPolicy.State
    )

    enum Tone: Equatable {
        case information
        case attention
        case danger
    }

    let title: String
    let detail: String
    let timing: String
    let systemImage: String
    let tone: Tone

    static func resolve(
        milestones: [ProtocolMilestone],
        snapshot: NodeSnapshot,
        now: Date = Date()
    ) -> MenuBarMilestonePresentation? {
        let frame = max(snapshot.frame, snapshot.lastReceivedFrame)
        let observed = snapshot.observedProtocolMilestones ?? [:]

        let candidates: [Candidate] = milestones.compactMap { milestone in
            let requiresAttention = ProtocolMilestonePresentationPolicy.requiresAttention(milestone)
            let state = ProtocolMilestonePresentationPolicy.state(
                for: milestone,
                currentFrame: frame,
                locallyObserved: observed[milestone.symbol] == milestone.targetFrame
            )
            guard state != .upcoming || requiresAttention else {
                return nil
            }
            if frame > milestone.targetFrame,
                !requiresAttention,
                frame - milestone.targetFrame
                    > ProtocolMilestonePresentationPolicy.completedOverviewRetentionFrames
            {
                return nil
            }
            return (milestone, state)
        }
        .sorted { lhs, rhs in
            let lhsAttention = ProtocolMilestonePresentationPolicy.requiresAttention(lhs.milestone)
            let rhsAttention = ProtocolMilestonePresentationPolicy.requiresAttention(rhs.milestone)
            if lhsAttention != rhsAttention { return lhsAttention }
            let lhsDistance =
                lhs.milestone.targetFrame > frame
                ? lhs.milestone.targetFrame - frame
                : frame - lhs.milestone.targetFrame
            let rhsDistance =
                rhs.milestone.targetFrame > frame
                ? rhs.milestone.targetFrame - frame
                : frame - rhs.milestone.targetFrame
            if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
            return lhs.milestone.symbol < rhs.milestone.symbol
        }

        guard let (milestone, state) = candidates.first else { return nil }
        let estimate = ProtocolMilestoneTiming.estimate(
            targetFrame: milestone.targetFrame,
            currentFrame: frame,
            framesPerMinute: snapshot.framesPerMinute,
            lowerFramesPerMinute: snapshot.lowerFramesPerMinute,
            upperFramesPerMinute: snapshot.upperFramesPerMinute,
            now: now
        )

        if milestone.installedSupport == .missing {
            return MenuBarMilestonePresentation(
                title: "Protocol support missing",
                detail: "The installed node does not include \(milestone.title).",
                timing: compactTiming(estimate.expectedAt, now: now),
                systemImage: "exclamationmark.shield.fill",
                tone: .danger
            )
        }
        if milestone.hasSourceConflict {
            return MenuBarMilestonePresentation(
                title: "Protocol source needs review",
                detail: "Executable declarations disagree for \(milestone.title).",
                timing: compactTiming(estimate.expectedAt, now: now),
                systemImage: "exclamationmark.triangle.fill",
                tone: .danger
            )
        }

        switch state {
        case .imminent:
            return MenuBarMilestonePresentation(
                title: milestone.title,
                detail: "\(estimate.framesRemaining.grouped) frames until target \(milestone.targetFrame.grouped).",
                timing: compactTiming(estimate.expectedAt, now: now),
                systemImage: "scope",
                tone: .attention
            )
        case .passedLocallyObserved:
            return MenuBarMilestonePresentation(
                title: "\(milestone.title) applied",
                detail: "The protocol transition was observed locally.",
                timing: "Complete",
                systemImage: "checkmark.circle.fill",
                tone: .information
            )
        case .passedWithoutLocalEvidence:
            return MenuBarMilestonePresentation(
                title: "\(milestone.title) awaiting evidence",
                detail: "The target passed; local transition evidence is still pending.",
                timing: "Review",
                systemImage: "clock.badge.exclamationmark",
                tone: .attention
            )
        case .upcoming:
            return nil
        }
    }

    private static func compactTiming(_ date: Date?, now: Date) -> String {
        guard let date else { return "Soon" }
        let seconds = max(Int(date.timeIntervalSince(now)), 0)
        if seconds >= 86_400 { return "~\(seconds / 86_400)d" }
        if seconds >= 3_600 { return "~\(seconds / 3_600)h \((seconds % 3_600) / 60)m" }
        return "~\(max(seconds / 60, 1))m"
    }
}
