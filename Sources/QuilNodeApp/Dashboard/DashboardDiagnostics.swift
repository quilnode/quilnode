import AppKit
import Charts
import SwiftUI

#if canImport(QuilNodeCore)
    import QuilNodeCore
#endif

extension DashboardView {
    var diagnosticsSection: some View {
        DisclosureGroup(isExpanded: $diagnosticsExpanded) {
            VStack(spacing: 0) {
                IdentityRow(
                    label: "Version", value: monitor.snapshot.version ?? "—", systemImage: "shippingbox",
                    showsCopy: false, privacyField: nil)
                Divider().padding(.leading, 42)
                IdentityRow(
                    label: "Process",
                    value: monitor.snapshot.processID.map { "PID \($0)" } ?? "Not running",
                    systemImage: "terminal",
                    showsCopy: false,
                    privacyField: nil
                )
                Divider().padding(.leading, 42)
                if monitor.snapshot.recentWarnings.isEmpty {
                    HStack(spacing: 12) {
                        DashboardCircleIcon(systemImage: "checkmark", tint: theme.colors.success, size: 38)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("No recent local warnings")
                                .font(.subheadline.weight(.semibold))
                            Text("The latest local log sample is clean.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(16)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(monitor.snapshot.recentWarnings.enumerated()), id: \.offset) { index, warning in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(theme.colors.warning)
                                    .padding(.top, 1)
                                Text(PrivacySanitizer.display(warning, enabled: privacyModeEnabled))
                                    .font(.caption.monospaced())
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(13)

                            if index < monitor.snapshot.recentWarnings.count - 1 {
                                Divider().padding(.leading, 40)
                            }
                        }
                    }
                }
            }
            .padding(.top, 10)
        } label: {
            HStack {
                Label("Technical diagnostics", systemImage: "wrench.and.screwdriver")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(
                    monitor.snapshot.recentWarnings.isEmpty
                        ? "No recent warnings"
                        : "\(monitor.snapshot.recentWarnings.count) recent messages"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .controlSurface()
    }

    var provingPhaseTitle: String {
        if let startupTitle = nodeObservation.primaryTitle { return startupTitle }
        return participationEvidence.title
    }

    @ViewBuilder
    var provingPhaseTitleView: some View {
        if let startupTitle = nodeObservation.primaryTitle {
            Text(startupTitle)
        } else if !monitor.snapshot.isRunning {
            Text("Node offline")
        } else if monitor.snapshot.activeShards > 0 {
            PrivacyProtectedPhrase(
                prefix: "Active on ",
                value: String(monitor.snapshot.activeShards),
                suffix: " shards",
                field: .activeShardCount
            )
        } else {
            Text(provingPhaseTitle)
        }
    }

    var provingPhaseDetail: String {
        if let startupDetail = nodeObservation.primaryDetail { return startupDetail }
        return participationEvidence.detail
    }

    var overviewTint: Color {
        if monitor.observationPhase == .checkingProcess { return theme.colors.info }
        if monitor.observationPhase == .loadingTelemetry {
            return monitor.snapshot.isRunning ? theme.colors.success : theme.colors.danger
        }
        if chainProgress.state == .archiveRecovery { return theme.colors.info }
        if monitor.snapshot.activeShards > 0 { return theme.colors.success }
        if monitor.snapshot.isRunning { return theme.colors.warning }
        return theme.colors.danger
    }

    var healthTint: Color {
        switch monitor.snapshot.health {
        case .active: theme.colors.success
        case .joining: theme.colors.warning
        case .syncing: theme.colors.info
        case .stalled: theme.colors.warning
        case .stopped: theme.colors.danger
        }
    }

    var overviewEyebrow: String {
        nodeObservation.hasLiveTelemetry ? DashboardCopy.Overview.eyebrow : "LOCAL OBSERVATION"
    }

    @ViewBuilder
    var allocationBreakdownView: some View {
        let active = monitor.snapshot.activeShards
        let joining = monitor.snapshot.pendingJoins
        if active > 0 && joining > 0 {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                PrivacyProtectedText(value: String(active), field: .activeShardCount)
                Text(" active · ")
                PrivacyProtectedText(value: String(joining), field: .allocationCount)
                Text(" joining")
            }
            .accessibilityElement(children: .combine)
        } else if active > 0 {
            PrivacyProtectedPhrase(
                value: String(active),
                suffix: " active",
                field: .activeShardCount
            )
        } else if joining > 0 {
            PrivacyProtectedPhrase(
                value: String(joining),
                suffix: " joining",
                field: .allocationCount
            )
        } else if monitor.snapshot.totalAllocations > 0 {
            PrivacyProtectedPhrase(
                value: String(monitor.snapshot.totalAllocations),
                suffix: " waiting",
                field: .allocationCount
            )
        } else {
            Text("No allocations")
        }
    }

    var effectiveFrame: UInt64 {
        max(monitor.snapshot.frame, monitor.snapshot.lastReceivedFrame)
    }

    var effectiveGlobalHead: UInt64 {
        max(monitor.snapshot.lastGlobalHeadFrame, effectiveFrame)
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

    var epochProgressLabel: String {
        return
            "\(max(monitor.snapshot.epochLength, 1).grouped) frames per epoch · next boundary \((effectiveFrame + framesUntilEpoch).grouped)"
    }

    var epochETA: String {
        if chainProgress.state == .archiveRecovery { return "Waiting for archive recovery" }
        return EpochEstimateFormatter.detailed(
            framesRemaining: framesUntilEpoch,
            framesPerMinute: monitor.snapshot.framesPerMinute
        )
    }

    var epochCompactETA: String {
        if chainProgress.state == .archiveRecovery { return "Waiting on archives" }
        return EpochEstimateFormatter.compact(
            framesRemaining: framesUntilEpoch,
            framesPerMinute: monitor.snapshot.framesPerMinute
        )
    }

    var syncGap: UInt64 {
        effectiveGlobalHead > effectiveFrame ? effectiveGlobalHead - effectiveFrame : 0
    }

    var syncGapDetail: String {
        return syncGap == 0 ? "Local head caught up" : "\(syncGap.grouped) frames behind"
    }

    var statusDetail: String {
        return "\(monitor.snapshot.workDetail) · live sample \(refreshTime)"
    }

    var allocationDetail: String {
        DashboardCopy.Activity.allocationDetail(
            activeShards: monitor.snapshot.activeShards,
            pendingJoins: monitor.snapshot.pendingJoins
        )
    }

    var framePace: String {
        if chainProgress.state == .archiveRecovery { return "Network hold" }
        return monitor.snapshot.framesPerMinute.map { String(format: "%.1f/min", $0) } ?? "Learning…"
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

    var rewardStatusDetail: String {
        participationEvidence.rewardDetail
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

    var refreshTime: String {
        return monitor.snapshot.collectedAt.formatted(date: .omitted, time: .standard)
    }

    var memoryFraction: Double {
        guard let memory = monitor.snapshot.memoryMB else { return 0 }
        let totalMB = Double(ProcessInfo.processInfo.physicalMemory) / 1_048_576
        return min(max(memory / totalMB, 0), 1)
    }

}
